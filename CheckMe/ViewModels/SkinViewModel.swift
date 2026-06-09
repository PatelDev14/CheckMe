import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Scan Phase (skin)

enum SkinScanPhase: Equatable {
    case idle
    case recognizingText
    case extractingProduct
    case analyzingSkin
    case categorizingIngredients
    case complete
    case failed(String)

    static func == (lhs: SkinScanPhase, rhs: SkinScanPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recognizingText, .recognizingText),
             (.extractingProduct, .extractingProduct), (.analyzingSkin, .analyzingSkin),
             (.categorizingIngredients, .categorizingIngredients), (.complete, .complete):
            return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var statusText: String {
        switch self {
        case .idle:                    return ""
        case .recognizingText:         return "Reading label…"
        case .extractingProduct:       return "Identifying product…"
        case .analyzingSkin:           return "Checking skin compatibility…"
        case .categorizingIngredients: return "Categorising ingredients…"
        case .complete:                return "Analysis complete"
        case .failed(let msg):         return msg
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
final class SkinViewModel {

    // MARK: - State

    var phase: SkinScanPhase = .idle
    var currentScan: ScanModel?

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

    func processCapture(_ image: UIImage) async {
        reset()
        phase = .recognizingText

        do {
            let rawText = try await TextRecognizer.recognizeText(from: image)
            guard !rawText.isEmpty else { throw RecognitionError.noTextFound }

            let ingredientBlock = TextRecognizer.extractIngredientBlock(from: rawText)

            phase = .extractingProduct
            let productInfo = try await extractProductInfo(from: ingredientBlock, fullText: rawText)
            let validatedName = validateProductName(productInfo.productName, against: rawText)
            partialProductName = validatedName
            partialIngredients = productInfo.cleanedIngredients

            let cleanedIngredients = deduplicatedIngredients(
                expandIngredients(productInfo.cleanedIngredients)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count >= 2 && $0.contains(where: { $0.isLetter }) }
            )
            partialIngredients = cleanedIngredients

            guard !cleanedIngredients.isEmpty else { throw RecognitionError.notAnIngredientLabel }

            phase = .analyzingSkin
            let skinPrediction = try await analyzeSkin(
                productName: validatedName,
                ingredients: cleanedIngredients
            )

            // Categorise ingredients into functional groups for the breakdown card
            phase = .categorizingIngredients
            let categories = try? await categorizeIngredients(cleanedIngredients)

            let itemName = validatedName
            let scan = ScanModel(
                itemName: itemName.isEmpty ? "Unknown Product" : itemName,
                ingredients: cleanedIngredients,
                category: .skin
            )
            scan.capturedImagePath = saveCapturedImage(image)
            scan.skinPrediction = SavedSkinPrediction(from: skinPrediction)
            if let categories { scan.skinCategories = SavedSkinCategories(from: categories) }
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

    // MARK: - Image Persistence

    private func saveCapturedImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let filename = "scan_\(UUID().uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? data.write(to: url)
        return filename
    }

    // MARK: - Helpers

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

    private func splitIngredientString(_ text: String) -> [String] {
        var results: [String] = []
        var current = ""
        var depth = 0

        for char in text {
            switch char {
            case "(", "[": depth += 1; current.append(char)
            case ")", "]": depth = max(0, depth - 1); current.append(char)
            case ",", ";":
                if depth == 0 {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { results.append(trimmed) }
                    current = ""
                } else {
                    current.append(char)
                }
            default: current.append(char)
            }
        }
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { results.append(last) }
        return results
    }

    private func expandIngredients(_ ingredients: [String]) -> [String] {
        ingredients.flatMap { entry -> [String] in
            let topLevel = entry.replacingOccurrences(
                of: #"\([^)]*\)|\[[^\]]*\]"#, with: "", options: .regularExpression
            )
            if topLevel.contains(",") || topLevel.contains(";") {
                let split = splitIngredientString(entry)
                return split.count > 1 ? split : [entry]
            }
            return [entry]
        }
    }

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

    private func extractProductInfo(from ingredientBlock: String, fullText: String) async throws -> SkinProductInfo {
        let session = LanguageModelSession(
            instructions: """
            You are a strict skincare label parser. Your ONLY job is to extract information that is \
            literally visible in the OCR text. Never infer, guess, or fabricate anything. \
            If a product name is not clearly visible, you MUST return exactly "Unknown Product".
            """
        )
        let prompt = """
        You are reading OCR text scanned from a real skincare or cosmetic product label. \
        Extract every ingredient and the product name precisely as described below.

        ── FULL LABEL TEXT ──────────────────────────────────
        \(fullText.prefix(2000))

        ── DETECTED INGREDIENT SECTION ─────────────────────
        \(ingredientBlock.prefix(3000))

        ═══════════════════════════════════════════════════════
        RULES
        ═══════════════════════════════════════════════════════

        PRODUCT NAME
        • Use ONLY text that explicitly identifies the product's brand and name.
        • VERIFICATION STEP: Before returning the product name, confirm each word you include actually appears in the OCR text provided. If you cannot verify it, return exactly: Unknown Product
        • If no clear product name is visible, return exactly: Unknown Product
        • NEVER guess, infer, or fabricate a name from prior knowledge or brand recognition.

        INGREDIENTS
        • CRITICAL ORDER RULE: Return ingredients in the EXACT ORDER they appear on the label. Do NOT sort alphabetically, group by type, or reorder in any way.
        • Extract EVERY ingredient listed, in the order they appear on the label.
        • Skincare labels often use INCI (International Nomenclature) names — keep them as-is.
        • Each top-level item (comma-separated outside parentheses) is one array entry.
        • Strip percentages, asterisks, footnote markers, and OCR noise.
        • Do NOT include usage instructions, warnings, or marketing copy.
        • If no ingredient list is detectable, return an empty array.
        """
        let result = try await session.respond(to: prompt, generating: SkinProductInfo.self)
        return result.content
    }

    private func analyzeSkin(productName: String, ingredients: [String]) async throws -> SkinPrediction {
        let context = profileStore.profile.skinPromptContext
        let ingredientList = ingredients.joined(separator: ", ")

        let systemInstructions = context.isEmpty
            ? "You are a dermatology-informed skincare ingredient analyst. Provide neutral, factual overviews only. Never flag or warn about ingredients when no user profile is provided."
            : "You are a dermatology-informed skincare ingredient analyst evaluating a product for a specific user. \(context)"

        let session = LanguageModelSession(instructions: systemInstructions)

        let hasBlacklist = !profileStore.profile.blacklistedIngredients.isEmpty
        let noProfileRules = """
        CRITICAL — No user skin profile is set:
        - rating MUST start with exactly "Skin Friendly" followed by one neutral sentence describing what the product does.
        \(hasBlacklist
            ? "- irritants: ONLY include ingredients from the PERSONAL BLACKLIST above that are present in this product. Empty array if none match."
            : "- irritants MUST be an empty array. Do NOT list any ingredients here.")
        - cautions MUST be an empty array. Do NOT list any ingredients here.
        - tip: One friendly usage tip (not a health or safety warning).
        \(hasBlacklist ? "" : "Do NOT flag, warn about, or mention irritants, allergens, or risks of any kind.")
        """

        let hasProfileRules = """
        RATING — use EXACTLY one of these phrases:
        - "Skin Friendly" — minimal concerns for this user, generally well-tolerated
        - "Moderate Concern" — 1-2 ingredients worth being cautious about for their profile
        - "High Concern" — known irritants, allergens, or ingredients conflicting with their conditions
        Follow with one sentence explaining why, tailored to their skin profile.

        IRRITANTS — ingredients this user should avoid based on their stated skin conditions/concerns.
        Max 5. Empty array if none apply.

        CAUTIONS — mild concerns specific to this user's skin type/conditions.
        Max 5. Empty array if none apply.

        TIP — one practical tip personalised to their skin profile.
        """

        let blacklistAddendum = profileStore.profile.blacklistPromptAddendum
        let prompt = """
        Analyze this personal care product.

        Product: \(productName)
        Ingredients: \(ingredientList)

        User Skin Profile: \(context.isEmpty ? "NONE — user has not completed their skin profile" : context)
        \(blacklistAddendum)

        \(context.isEmpty ? noProfileRules : hasProfileRules)
        """
        let result = try await session.respond(to: prompt, generating: SkinPrediction.self)
        return result.content
    }

    // MARK: - Ingredient Categorisation

    private func categorizeIngredients(_ ingredients: [String]) async throws -> SkinIngredientCategories {
        let session = LanguageModelSession(
            instructions: "You are a cosmetic chemist. Classify skincare ingredients into functional categories based on their established role in formulations."
        )
        let ingredientList = ingredients.joined(separator: "\n- ")
        let prompt = """
        Classify each ingredient below into exactly ONE functional category.
        Every ingredient must appear in exactly one category — none may be omitted.
        Do not invent ingredients not in the list.

        Ingredients:
        - \(ingredientList)

        Categories and definitions:
        • actives — bioactive ingredients that change skin chemistry (retinol, niacinamide, AHAs, BHAs, vitamin C, peptides, bakuchiol)
        • humectants — draw moisture into skin (glycerin, hyaluronic acid, panthenol, aloe vera, urea, sodium PCA)
        • emollients — soften skin, fill lipid gaps (squalane, jojoba oil, cetyl/cetearyl alcohol, shea butter, triglycerides, fatty acids)
        • occlusives — seal moisture in, form barrier (petrolatum, dimethicone, beeswax, lanolin, mineral oil, zinc oxide, titanium dioxide)
        • preservatives — prevent microbial growth (phenoxyethanol, parabens, benzyl alcohol, ethylhexylglycerin, sodium benzoate, DMDM hydantoin)
        • fragrances — scent compounds natural or synthetic (parfum, fragrance, linalool, limonene, essential oils, citronellol)
        • surfactants — cleanse via surface tension reduction (SLS, SLES, cocamidopropyl betaine, coco-glucoside, ammonium lauryl sulfate)
        • other — everything else (water, thickeners like carbomer/xanthan gum, pH adjusters, chelators like EDTA, colorants, emulsifiers, solvents, sunscreen filters)
        """
        let result = try await session.respond(to: prompt, generating: SkinIngredientCategories.self)
        return result.content
    }

    // MARK: - Per-Ingredient Skin Analysis

    func analyzeSkinIngredient(_ name: String, in scan: ScanModel) async throws -> SkinIngredientModel {
        let descriptor = FetchDescriptor<SkinIngredientModel>(
            predicate: #Predicate { $0.name == name }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            if cached.keyFacts.isEmpty {
                modelContext.delete(cached)
                try? modelContext.save()
            } else {
                return cached
            }
        }

        let context = profileStore.profile.skinPromptContext
        let allIngredients = scan.ingredients.joined(separator: ", ")

        let session = LanguageModelSession(
            instructions: "You are a cosmetic chemist and skincare expert explaining ingredients to consumers."
        )
        let prompt = """
        Analyze the skincare ingredient "\(name)" as it appears in "\(scan.itemName)".

        Full ingredient list for context: \(allIngredients.prefix(400))
        \(context.isEmpty ? "" : "\nUser skin profile: \(context)")

        Provide a rich, detailed analysis including:
        - explanation: What this ingredient is and its role in skincare (1-2 sentences)
        - skinEffect: How skin typically responds — common effects and benefits or risks (1-2 sentences)
        - suitability: Whether it suits this user's specific skin type and conditions (1 personalized sentence)
        - safetyRating: One of 'Generally Safe', 'Monitor', 'Use Caution', 'Avoid'
        - origin: One of 'Natural', 'Semi-Synthetic', 'Synthetic'
        - penetrationDepth: One of 'Surface', 'Epidermal', 'Dermal'
        - keyFacts: Exactly 3 short scannable skincare facts (6-12 words each)

        Be specific to skincare, not food digestion.
        """
        let result = try await session.respond(to: prompt, generating: SkinIngredientAnalysis.self)

        let model = SkinIngredientModel(
            name: name,
            explanation: result.content.explanation,
            skinEffect: result.content.skinEffect,
            suitability: result.content.suitability,
            safetyRating: result.content.safetyRating,
            origin: result.content.origin,
            penetrationDepth: result.content.penetrationDepth,
            keyFacts: result.content.keyFacts
        )
        modelContext.insert(model)
        try? modelContext.save()
        return model
    }

    // MARK: - Re-analysis

    func reanalyze(scan: ScanModel) async {
        phase = .analyzingSkin
        do {
            let prediction = try await analyzeSkin(
                productName: scan.itemName,
                ingredients: scan.ingredients
            )

            // Delete the old SwiftData object before inserting the replacement.
            // Without this, the old record stays orphaned in the context and SwiftData
            // may not persist the newly assigned relationship on the first save attempt.
            if let old = scan.skinPrediction { modelContext.delete(old) }

            let newPrediction = SavedSkinPrediction(from: prediction)
            modelContext.insert(newPrediction)
            scan.skinPrediction = newPrediction

            try modelContext.save()
            currentScan = scan
            phase = .complete
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
