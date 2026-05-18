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
            let validatedName = validateProductName(productInfo.productName, against: rawText)
            partialProductName = validatedName
            partialIngredients = productInfo.cleanedIngredients

            print("[IngredientsViewModel] AI extraction complete: \(productInfo.productName), \(productInfo.cleanedIngredients.count) ingredients")

            // Post-process the AI's ingredient list in four passes:
            // 1. Expand — split any entries that are really a combined comma-separated list
            //    (handles the failure mode where the AI returns all ingredients as one string)
            // 2. Trim — strip leading/trailing whitespace from each entry
            // 3. Filter — drop pure noise (no letters, fewer than 2 chars)
            // 4. Deduplicate — remove exact duplicates while preserving original order
            let cleanedIngredients = deduplicatedIngredients(
                extractParentheticalIngredients(
                    expandIngredients(productInfo.cleanedIngredients)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { ingredient in
                            ingredient.count >= 2 &&
                            ingredient.contains(where: { $0.isLetter })
                        }
                )
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
            let itemName = validatedName
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
            scan.capturedImagePath = saveCapturedImage(image)
            modelContext.insert(scan)
            try modelContext.save()

            currentScan = scan
            phase = .complete

        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func saveCapturedImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let filename = "scan_\(UUID().uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? data.write(to: url)
        return filename
    }

    func reset() {
        phase = .idle
        currentScan = nil
        partialProductName = ""
        partialIngredients = []
    }

    // MARK: - Helpers

    /// Cross-checks the AI's returned product name against the raw OCR text.
    /// If fewer than 1/3 of the substantive words from the name appear in the OCR text,
    /// the model likely hallucinated the name — returns "Unknown Product" instead.
    private func validateProductName(_ name: String, against ocrText: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "Unknown Product" else { return "Unknown Product" }

        let stopWords: Set<String> = ["the", "and", "with", "for", "by", "of", "in"]
        let nameWords = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { $0.count >= 3 && !stopWords.contains($0) }

        guard !nameWords.isEmpty else { return trimmed }

        let ocrLower = ocrText.lowercased()
        let matchCount = nameWords.filter { ocrLower.contains($0) }.count
        let requiredMatches = max(1, nameWords.count / 3)
        return matchCount >= requiredMatches ? trimmed : "Unknown Product"
    }

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

    /// Extracts sub-ingredients from parentheses when there are 3+ distinct items.
    /// Example:
    ///   Input:  ["Seasoning (maltodextrin, sugar, soy protein, monosodium glutamate)"]
    ///   Output: ["Seasoning (maltodextrin, sugar, soy protein, monosodium glutamate)", "Maltodextrin", "Sugar", "Soy Protein", "Monosodium Glutamate"]
    ///
    /// This handles complex ingredients where the parentheses contain a full sub-ingredient list
    /// that should be available for individual allergy/trigger matching.
    private func extractParentheticalIngredients(_ ingredients: [String]) -> [String] {
        var result = ingredients

        for ingredient in ingredients {
            // Find parenthetical content
            guard let openParen = ingredient.firstIndex(of: "("),
                  let closeParen = ingredient.lastIndex(of: ")") else {
                continue
            }

            let parenContent = String(ingredient[ingredient.index(after: openParen)..<closeParen])

            // Split the parenthetical content by comma
            let subItems = splitIngredientString(parenContent)

            // Only extract as separate ingredients if there are 3+ sub-items
            // (1-2 items are likely just clarifications, not full ingredient lists)
            if subItems.count >= 3 {
                result.append(contentsOf: subItems)
            }
        }

        return result
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
        • VERIFICATION STEP: Before returning the product name, check that each word you include actually appears somewhere in the OCR text provided. If you cannot verify the name against the text, return exactly: Unknown Product
        • If no clear product name is visible, return exactly: Unknown Product
        • NEVER guess, infer, or fabricate a name from ingredients, prior knowledge, or brand recognition.
        • NEVER use an ingredient name or food category as the product name.

        INGREDIENTS — completeness and ORDER are the top priorities
        ────────────────────────────────────────────────────────────
        • CRITICAL ORDER RULE: Return all ingredients in the EXACT ORDER they appear on the label, first to last. Do NOT sort alphabetically, group by type, or reorder in any way.

        • Extract EVERY ingredient listed, including those after phrases like:
            – "and less than 2% of:"    (include everything that follows)
            – "contains less than 2% of:"
            – "with less than X% of:"
            – "in 2% or less of:"
        • Include vitamins and minerals listed as ingredients, e.g.:
            "Niacinamide", "Thiamin Mononitrate (Vitamin B1)", "Folic Acid"

        CRITICAL — Handle parenthetical sub-ingredients properly:
        ──────────────────────────────────────────────────────────────────────────────
        For ingredients with detailed sub-ingredient lists in parentheses:
            ✓ CORRECT: Extract both the main ingredient AND individual sub-ingredients:
              Input label: "Seasoning (maltodextrin, sugar, soy protein, monosodium glutamate)"
              Output: ["Seasoning (maltodextrin, sugar, soy protein, monosodium glutamate)", "Maltodextrin", "Sugar", "Soy Protein", "Monosodium Glutamate"]
            ✓ ALSO CORRECT: Simple parenthetical notes stay attached:
              "Enriched Flour (Wheat, Niacin)" → ONE entry if the sub-items are just a short clarification
        • Use your judgment: If parentheses contain 3+ distinct sub-ingredients, extract them individually.
        • If parentheses contain only 1-2 clarification items, keep them attached.

        • OCR sometimes splits a single ingredient across two lines — join them logically.
        • Each top-level item (comma-separated at the top level, OUTSIDE parentheses) is one array entry.
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
            ? "You are a neutral food analyst. Provide purely factual, non-alarmist overviews of food products. Never flag or warn about ingredients when no user profile is provided."
            : "You are a gut health specialist evaluating food for a specific user. \(context)"

        let session = LanguageModelSession(instructions: systemInstructions)

        let noProfileRules = """
        CRITICAL — No user profile is set:
        - prediction MUST start with exactly "Gut Friendly" followed by one neutral, factual sentence describing what the product is.
        - triggers MUST be an empty array. Do NOT list any ingredients here.
        - cautions MUST be an empty array. Do NOT list any ingredients here.
        - tip: One friendly, positive note (e.g. how to enjoy the product, not a health warning).
        Do NOT flag, warn about, or mention allergens, additives, or risks of any kind.
        """

        let hasProfileRules = """
        1. prediction: Use EXACTLY one of these phrases:
           - "Gut Friendly" — minimal concerns for this user
           - "Moderate Risk" — 1–2 concerns worth noting
           - "High Risk" — 3+ serious concerns or a known allergen for this user
           Follow with one sentence explaining why, tailored to their profile.

        2. triggers: Ingredients this user should AVOID based on their stated allergies/conditions.
           Empty array if none apply.

        3. cautions: Ingredients with mild concerns for this specific user's profile.
           Empty array if none apply.

        4. tip: One practical tip personalised to their profile.
        """

        let prompt = """
        Analyze this food product.

        Product: \(productName)
        Ingredients: \(ingredientList)

        User Profile: \(context.isEmpty ? "NONE — user has not completed their health profile" : context)

        \(context.isEmpty ? noProfileRules : hasProfileRules)
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

            // Delete the old SwiftData objects before inserting replacements.
            // Without this, the old records stay orphaned in the context and SwiftData
            // may not persist the newly assigned relationship on the first save attempt.
            if let old = scan.gutPrediction { modelContext.delete(old) }

            let newGutPrediction = SavedGutPrediction(from: gutPrediction)
            modelContext.insert(newGutPrediction)
            scan.gutPrediction = newGutPrediction

            phase = .analyzingSummary
            let summary = try await generateSummary(
                productName: scan.itemName,
                ingredients: scan.ingredients
            )

            if let old = scan.summary { modelContext.delete(old) }

            let newSummary = GeneralSummaryModel(
                overview: summary.overview,
                digestionProcess: summary.digestionProcess,
                complexity: summary.complexity
            )
            modelContext.insert(newSummary)
            scan.summary = newSummary

            try modelContext.save()
            currentScan = scan
            phase = .complete
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
