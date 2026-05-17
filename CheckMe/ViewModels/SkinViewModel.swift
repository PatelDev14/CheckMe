import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Scan Phase (skin)

enum SkinScanPhase: Equatable {
    case idle
    case recognizingText
    case extractingProduct
    case analyzingSkin
    case complete
    case failed(String)

    static func == (lhs: SkinScanPhase, rhs: SkinScanPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recognizingText, .recognizingText),
             (.extractingProduct, .extractingProduct), (.analyzingSkin, .analyzingSkin),
             (.complete, .complete):
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
        case .analyzingSkin:      return "Checking skin compatibility…"
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

            let itemName = validatedName
            let scan = ScanModel(
                itemName: itemName.isEmpty ? "Unknown Product" : itemName,
                ingredients: cleanedIngredients,
                category: .skin
            )
            scan.skinPrediction = SavedSkinPrediction(from: skinPrediction)
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
            ? "You are a dermatology-informed skincare ingredient analyst. Provide factual information only."
            : "You are a dermatology-informed skincare ingredient analyst evaluating a product for a specific user. \(context)"

        let session = LanguageModelSession(instructions: systemInstructions)
        let prompt = """
        Analyze this skincare product for skin compatibility.

        Product: \(productName)
        Ingredients: \(ingredientList)

        User Skin Profile: \(context.isEmpty ? "NO PROFILE PROVIDED" : context)

        RATING — use EXACTLY one of these phrases:
        - "Skin Friendly" — minimal concerns, generally well-tolerated
        - "Moderate Concern" — 1-2 ingredients worth being cautious about
        - "High Concern" — known irritants, allergens, or ingredients conflicting with user's conditions
        Follow with one sentence explaining why.

        IRRITANTS — ingredients the user should avoid:
        - Flag: known allergens for their conditions, strong acids at irritating concentrations,
          essential oils for sensitive/rosacea skin, formaldehyde releasers, MI/MCI preservatives.
        - If no user profile: flag universally problematic ingredients (strong irritants, known allergens).
        - Max 5. Empty array if none.

        CAUTIONS — mild concerns:
        - Comedogenic ingredients for acne-prone skin (coconut oil, isopropyl myristate, etc.)
        - Synthetic fragrance / parfum for sensitive skin
        - High-alcohol formulations for dry skin
        - Common sensitizers even if not severe
        - Max 5. Empty array if none.

        TIP — one practical tip for using this product safely given their skin profile.
        """
        let result = try await session.respond(to: prompt, generating: SkinPrediction.self)
        return result.content
    }

    // MARK: - Per-Ingredient Skin Analysis

    func analyzeSkinIngredient(_ name: String, in scan: ScanModel) async throws -> SkinIngredientModel {
        let descriptor = FetchDescriptor<SkinIngredientModel>(
            predicate: #Predicate { $0.name == name }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            return cached
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

        Provide:
        - explanation: What this ingredient is and its role in skincare (1-2 sentences)
        - skinEffect: How skin typically responds to it — common effects and benefits or risks (1-2 sentences)
        - suitability: Whether it is suitable for this user's specific skin type and conditions (1 sentence, personalized)

        Be specific to skincare, not food digestion.
        """
        let result = try await session.respond(to: prompt, generating: SkinIngredientAnalysis.self)

        let model = SkinIngredientModel(
            name: name,
            explanation: result.content.explanation,
            skinEffect: result.content.skinEffect,
            suitability: result.content.suitability
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
            scan.skinPrediction = SavedSkinPrediction(from: prediction)
            try modelContext.save()
            currentScan = scan
            phase = .complete
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
