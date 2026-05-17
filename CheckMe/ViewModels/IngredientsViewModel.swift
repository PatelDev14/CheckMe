import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Scan Phase

/// Tracks progress through the multi-step OCR → AI → persist pipeline.
/// The UI observes this to show the right loading message and navigation.
enum ScanPhase: Equatable {
    case idle
    case recognizingText        // Vision OCR is running
    case extractingProduct      // AI parsing product name + clean ingredient list
    case analyzingGut           // AI generating personalized gut prediction
    case analyzingSummary       // AI generating general product summary
    case complete               // All steps done; currentScan is populated
    case failed(String)         // Holds the user-facing error message

    static func == (lhs: ScanPhase, rhs: ScanPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recognizingText, .recognizingText),
             (.extractingProduct, .extractingProduct), (.analyzingGut, .analyzingGut),
             (.analyzingSummary, .analyzingSummary), (.complete, .complete):
            return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var statusText: String {
        switch self {
        case .idle:               return ""
        case .recognizingText:    return "Reading label…"
        case .extractingProduct:  return "Identifying product…"
        case .analyzingGut:       return "Checking gut compatibility…"
        case .analyzingSummary:   return "Generating summary…"
        case .complete:           return "Analysis complete"
        case .failed(let msg):    return msg
        }
    }

    var isProcessing: Bool {
        switch self { case .idle, .complete, .failed: return false; default: return true }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class IngredientsViewModel {

    // MARK: - State

    var phase: ScanPhase = .idle
    var currentScan: ScanModel?

    // Shown incrementally in the UI before the full scan is persisted
    var partialProductName: String = ""
    var partialIngredients: [String] = []

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let profileStore: UserProfileStore

    // MARK: - Init

    init(modelContext: ModelContext, profileStore: UserProfileStore) {
        self.modelContext = modelContext
        self.profileStore = profileStore
    }

    // MARK: - Main Pipeline

    /// Runs the full scan pipeline: OCR → AI product parse → AI gut analysis → AI summary → persist.
    /// Call this with a UIImage from the camera capture.
    func processCapture(_ image: UIImage) async {
        reset()
        phase = .recognizingText

        do {
            print("[IngredientsViewModel] Starting scan pipeline with image size: \(image.size)")

            // Step 1: Vision OCR — extract all text from the label photo
            print("[IngredientsViewModel] Calling TextRecognizer.recognizeText...")
            let rawText = try await TextRecognizer.recognizeText(from: image)

            print("[IngredientsViewModel] OCR complete. Text length: \(rawText.count)")
            guard !rawText.isEmpty else {
                print("[IngredientsViewModel] OCR returned empty text")
                throw RecognitionError.noTextFound
            }

            let ingredientBlock = TextRecognizer.extractIngredientBlock(from: rawText)
            print("[IngredientsViewModel] Ingredient block extracted. Length: \(ingredientBlock.count)")

            // Step 2: AI product parsing — name + clean ingredient list
            phase = .extractingProduct
            print("[IngredientsViewModel] Starting AI product extraction...")
            let productInfo = try await extractProductInfo(from: ingredientBlock, fullText: rawText)
            partialProductName = productInfo.productName
            partialIngredients = productInfo.cleanedIngredients

            print("[IngredientsViewModel] AI extraction complete: \(productInfo.productName), \(productInfo.cleanedIngredients.count) ingredients")

            // Post-process the AI's ingredient list in four passes:
            // 1. Expand — split any entries that are really a combined comma-separated list
            //    (handles the failure mode where the AI returns all ingredients as one string)
            // 2. Trim — strip leading/trailing whitespace from each entry
            // 3. Filter — drop pure noise (no letters, fewer than 2 chars)
            // 4. Deduplicate — remove exact duplicates while preserving original order
            let cleanedIngredients = deduplicatedIngredients(
                expandIngredients(productInfo.cleanedIngredients)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { ingredient in
                        ingredient.count >= 2 &&
                        ingredient.contains(where: { $0.isLetter })
                    }
            )
            // Update UI with the cleaned count so the processing overlay is accurate
            partialIngredients = cleanedIngredients
            print("[IngredientsViewModel] After post-processing: \(cleanedIngredients.count) ingredients")

            // If the AI found no ingredients, the photo likely wasn't a label
            guard !cleanedIngredients.isEmpty else {
                print("[IngredientsViewModel] AI found no ingredients — not an ingredient label")
                throw RecognitionError.notAnIngredientLabel
            }

            // Step 3: Personalized gut prediction
            phase = .analyzingGut
            let gutPrediction = try await analyzeGut(
                productName: productInfo.productName,
                ingredients: cleanedIngredients
            )

            // Step 4: General nutritional / formulation summary
            phase = .analyzingSummary
            let summary = try await generateSummary(
                productName: productInfo.productName,
                ingredients: cleanedIngredients
            )

            // Step 5: Persist to SwiftData
            // Normalise product name — treat empty string same as "Unknown Product"
            let itemName = productInfo.productName.trimmingCharacters(in: .whitespaces)
            let scan = ScanModel(
                itemName: itemName.isEmpty ? "Unknown Product" : itemName,
                ingredients: cleanedIngredients,
                category: .food
            )
            scan.gutPrediction = SavedGutPrediction(from: gutPrediction)
            scan.summary = GeneralSummaryModel(
                overview: summary.overview,
                digestionProcess: summary.digestionProcess,
                complexity: summary.complexity
            )
            modelContext.insert(scan)
            try modelContext.save()

            currentScan = scan
            phase = .complete

        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
        currentScan = nil
        partialProductName = ""
        partialIngredients = []
    }

    // MARK: - Helpers

    /// Splits a single ingredient string into individual ingredients at top-level commas,
    /// respecting parentheses and brackets so sub-ingredients stay attached to their parent.
    ///
    /// Example:
    ///   Input:  "Enriched Flour (Wheat, Niacin), Sugar, Palm Oil"
    ///   Output: ["Enriched Flour (Wheat, Niacin)", "Sugar", "Palm Oil"]
    ///
    /// This is the primary defense against the Foundation Models failure mode where the
    /// entire ingredient list is returned as a single array entry instead of being split.
    private func splitIngredientString(_ text: String) -> [String] {
        var results: [String] = []
        var current = ""
        var depth = 0  // tracks nesting inside () and []

        for char in text {
            switch char {
            case "(", "[":
                depth += 1
                current.append(char)
            case ")", "]":
                depth = max(0, depth - 1)
                current.append(char)
            case ",", ";":
                if depth == 0 {
                    // Top-level separator — end of one ingredient, start of next
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { results.append(trimmed) }
                    current = ""
                } else {
                    // Inside parentheses — keep as part of the current ingredient
                    current.append(char)
                }
            default:
                current.append(char)
            }
        }

        // Append the last ingredient after the loop
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { results.append(last) }

        return results
    }

    /// Expands any AI-returned ingredient entries that are actually comma-separated lists
    /// masquerading as a single string. Applies `splitIngredientString` to every entry
    /// so the result is always a flat list of individual ingredients.
    private func expandIngredients(_ ingredients: [String]) -> [String] {
        ingredients.flatMap { entry -> [String] in
            // Only split if the entry contains a comma outside of parentheses.
            // A quick heuristic: if stripping all parenthetical content still leaves
            // a comma, there are top-level separators to split on.
            let topLevel = entry.replacingOccurrences(
                of: #"\([^)]*\)|\[[^\]]*\]"#,
                with: "",
                options: .regularExpression
            )
            if topLevel.contains(",") || topLevel.contains(";") {
                let split = splitIngredientString(entry)
                // Only use the split result if it produced multiple items —
                // otherwise the original single entry is already clean.
                return split.count > 1 ? split : [entry]
            }
            return [entry]
        }
    }

    /// Removes exact-duplicate ingredient strings while preserving the original order.
    /// Comparison is case-insensitive so "Sugar" and "sugar" are treated as one entry.
    private func deduplicatedIngredients(_ ingredients: [String]) -> [String] {
        var seen = Set<String>()
        return ingredients.filter { ingredient in
            let key = ingredient.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    // MARK: - AI Steps

    private func extractProductInfo(from ingredientBlock: String, fullText: String) async throws -> ProductInfo {
        // A single-use session per request is the recommended pattern for FoundationModels
        print("[AI] Starting product info extraction with ingredient block length: \(ingredientBlock.count)")
        let session = LanguageModelSession(
            instructions: """
            You are a strict food label parser. Your ONLY job is to extract information that is \
            literally visible in the OCR text. Never infer, guess, or fabricate anything. \
            If a product name is not clearly visible, you MUST return exactly "Unknown Product".
            """
        )
        let prompt = """
        You are reading OCR text scanned from a real food or beverage product label. \
        Extract every ingredient and the product name precisely as described below.

        ── FULL LABEL TEXT ──────────────────────────────────
        \(fullText.prefix(2000))

        ── DETECTED INGREDIENT SECTION ─────────────────────
        \(ingredientBlock.prefix(3000))

        ═══════════════════════════════════════════════════════
        RULES — read every rule before responding.
        ═══════════════════════════════════════════════════════

        PRODUCT NAME
        ────────────
        • Use ONLY text that explicitly identifies the product's brand and name on the label.
        • If no clear product name is visible, return exactly: Unknown Product
        • NEVER guess, infer, or fabricate a name from ingredients or prior knowledge.
        • NEVER use an ingredient name or food category as the product name.

        INGREDIENTS — completeness is the top priority
        ───────────────────────────────────────────────
        • Extract EVERY ingredient listed, including those after phrases like:
            – "and less than 2% of:"    (include everything that follows)
            – "contains less than 2% of:"
            – "with less than X% of:"
            – "in 2% or less of:"
        • Include vitamins and minerals listed as ingredients, e.g.:
            "Niacinamide", "Thiamin Mononitrate (Vitamin B1)", "Folic Acid"
        • Keep parenthetical sub-ingredients attached to their parent, e.g.:
            "Enriched Flour (Wheat Flour, Niacin, Reduced Iron, Thiamin Mononitrate)"
        • OCR sometimes splits a single ingredient across two lines — join them logically.
        • Each top-level item in the comma-separated list is one array entry.
        • Strip: percentages (2%), asterisks (*), daggers (†), footnote symbols, bare numbers.
        • Do NOT include items from:
            – Nutrition Facts / Valeur Nutritive panel
            – Allergen statements ("Contains: milk, wheat, eggs")
            – "May contain" warnings
            – Serving size or calorie information
            – Marketing copy or usage instructions
        • If the label text contains BOTH English and French ingredient lists, extract ONLY
          the English list to avoid duplicates (French names appear after "Ingrédients:").
        • If no ingredient list is detectable at all, return an empty array — do NOT invent.

        EXAMPLE of a complex label you should handle correctly:
        Input: "Enriched flour (wheat, niacin, iron), sugar, palm oil, and less than 2% of: \
        salt, cinnamon, natural flavour, soy lecithin, thiamine hydrochloride, BHT."
        Output array: [
          "Enriched flour (wheat, niacin, iron)",
          "Sugar",
          "Palm oil",
          "Salt",
          "Cinnamon",
          "Natural flavour",
          "Soy lecithin",
          "Thiamine hydrochloride",
          "BHT"
        ]
        """
        let result = try await session.respond(to: prompt, generating: ProductInfo.self)
        print("[AI] Product info extracted: \(result.content.productName)")
        print("[AI] Ingredients: \(result.content.cleanedIngredients)")
        return result.content
    }

    private func analyzeGut(productName: String, ingredients: [String]) async throws -> GutPrediction {
        let context = profileStore.profile.foodPromptContext
        let ingredientList = ingredients.joined(separator: ", ")

        let systemInstructions = context.isEmpty
            ? "You are a neutral food analyst. Provide factual information only. Do NOT make health recommendations without a user profile to reference."
            : "You are a gut health specialist evaluating food for a specific user. \(context)"

        let session = LanguageModelSession(instructions: systemInstructions)
        let prompt = """
        Analyze this food product for gut-health and general nutritional concerns.

        Product: \(productName)
        Ingredients: \(ingredientList)

        User Profile: \(context.isEmpty ? "NO PROFILE PROVIDED" : context)

        Instructions:

        1. prediction: Use EXACTLY one of these phrases based on BOTH user-specific + general health concerns:
           - "Gut Friendly" — minimal concerns for this user
           - "Moderate Risk" — 1–2 concerns worth noting
           - "High Risk" — 3+ serious concerns or a known allergen
           Follow with one sentence explaining why.

        2. triggers: Ingredients this user should AVOID:
           - If user profile exists: ingredients conflicting with their allergies/conditions
           - If NO user profile: ingredients that are generally problematic (major allergens like peanuts, tree nuts, shellfish, or ingredients with significant health warnings)
           Be precise and name exact ingredients.

        3. cautions: Mild concerns for this user:
           - If user profile exists: ingredients that conflict with their profile (high sugar if diabetic-friendly, etc.)
           - If NO user profile: ingredients that have general nutritional concerns (high sugar, high sodium, artificial additives, common irritants like gelatin for some, etc.)
           Be specific with exact ingredient names.

        4. tip: One practical tip based on the product's ingredients and the user's profile (or general advice if no profile).

        Remember: Provide BOTH user-specific warnings (if profile exists) AND general health information (always).
        This helps users understand their product comprehensively.
        """
        let result = try await session.respond(to: prompt, generating: GutPrediction.self)
        return result.content
    }

    private func generateSummary(productName: String, ingredients: [String]) async throws -> GeneralSummary {
        let session = LanguageModelSession(
            instructions: "You are a nutritional educator providing clear, factual, non-alarmist overviews of food products."
        )
        let ingredientList = ingredients.joined(separator: ", ")
        let prompt = """
        Provide a concise summary of this food product based on its ingredients.

        Product: \(productName)
        Ingredients: \(ingredientList)

        Cover:
        1. What this product generally is (overview)
        2. How the body processes its main ingredients (digestion process)
        3. Whether the ingredient list is simple or complex (complexity assessment)

        Keep each field to 1–2 sentences. Neutral, informative tone — not alarmist.
        """
        let result = try await session.respond(to: prompt, generating: GeneralSummary.self)
        return result.content
    }

    // MARK: - Per-Ingredient Analysis

    /// Returns a detailed AI analysis for a single ingredient.
    /// Results are cached in SwiftData — subsequent calls for the same ingredient name
    /// skip the AI and return instantly.
    func analyzeIngredient(_ name: String, in scan: ScanModel) async throws -> IngredientsModel {
        // Check persistent cache before hitting the AI
        let descriptor = FetchDescriptor<IngredientsModel>(
            predicate: #Predicate { $0.name == name }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            return cached
        }

        let context = profileStore.profile.foodPromptContext
        let allIngredients = scan.ingredients.joined(separator: ", ")

        let session = LanguageModelSession(
            instructions: "You are a food science expert explaining ingredients to health-conscious consumers."
        )
        let prompt = """
        Analyze the ingredient "\(name)" as it appears in "\(scan.itemName)".

        Full ingredient list for context: \(allIngredients.prefix(400))
        \(context.isEmpty ? "" : "\nUser health context: \(context)")

        Provide:
        - explanation: What this ingredient is in plain English (1–2 sentences)
        - digestion: How the body processes it (1–2 sentences)
        - digestiveFeel: How it typically feels digestively — e.g. well-tolerated, may cause bloating (1 sentence)

        Tailor to the user's health context where relevant. Be specific, not generic.
        """
        let result = try await session.respond(to: prompt, generating: IngredientSummary.self)

        let model = IngredientsModel(
            name: name,
            explanation: result.content.explanation,
            digestion: result.content.digestion,
            digestiveFeel: result.content.digestiveFeel
        )
        modelContext.insert(model)
        try? modelContext.save()
        return model
    }

    // MARK: - Re-analysis

    /// Triggers a fresh AI analysis for an existing scan (e.g. after the user updates their profile).
    func reanalyze(scan: ScanModel) async {
        phase = .analyzingGut
        do {
            let gutPrediction = try await analyzeGut(
                productName: scan.itemName,
                ingredients: scan.ingredients
            )
            scan.gutPrediction = SavedGutPrediction(from: gutPrediction)

            phase = .analyzingSummary
            let summary = try await generateSummary(
                productName: scan.itemName,
                ingredients: scan.ingredients
            )
            scan.summary = GeneralSummaryModel(
                overview: summary.overview,
                digestionProcess: summary.digestionProcess,
                complexity: summary.complexity
            )
            try modelContext.save()
            currentScan = scan
            phase = .complete
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
