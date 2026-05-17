import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Scan Phase

enum NutritionScanPhase: Equatable {
    case idle
    case recognizingText        // Vision OCR
    case extractingNutrition    // AI parsing the numbers + product name
    case analyzingNutrition     // AI generating macro insight
    case complete
    case failed(String)

    static func == (lhs: NutritionScanPhase, rhs: NutritionScanPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recognizingText, .recognizingText),
             (.extractingNutrition, .extractingNutrition),
             (.analyzingNutrition, .analyzingNutrition),
             (.complete, .complete):
            return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var statusText: String {
        switch self {
        case .idle:                return ""
        case .recognizingText:     return "Reading nutrition panel…"
        case .extractingNutrition: return "Extracting nutrients…"
        case .analyzingNutrition:  return "Generating macro insight…"
        case .complete:            return "Analysis complete"
        case .failed(let msg):     return msg
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
final class NutritionViewModel {

    // MARK: - State

    var phase: NutritionScanPhase = .idle
    var currentScan: ScanModel?
    var partialProductName: String = ""

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let profileStore: UserProfileStore

    init(modelContext: ModelContext, profileStore: UserProfileStore) {
        self.modelContext = modelContext
        self.profileStore = profileStore
    }

    // MARK: - Main Pipeline

    func processCapture(_ image: UIImage) async {
        reset()
        phase = .recognizingText

        do {
            // Skip preprocessing for nutrition panels: the heavy sharpening/contrast that
            // helps ingredient labels on coloured packaging actively hurts number accuracy
            // on black-on-white nutrition tables (causes digit distortion in OCR).
            let rawText = try await TextRecognizer.recognizeText(from: image, preprocess: false)
            guard !rawText.isEmpty else { throw RecognitionError.noTextFound }

            // Pass the full OCR text straight to the AI — skipping extractNutritionBlock
            // avoids the fragile header-keyword matching that was the main source of false
            // "not detected" errors. The AI's @Guide descriptions are enough to parse it.
            phase = .extractingNutrition
            async let nameTask      = extractProductName(from: rawText)
            async let nutritionTask = parseNutritionFacts(from: rawText, fullText: rawText)
            let (rawName, extraction) = try await (nameTask, nutritionTask)

            let productName = validateProductName(rawName, against: rawText)
            partialProductName = productName

            guard SavedNutritionFacts(from: extraction).hasData else {
                throw RecognitionError.notANutritionLabel
            }

            // Generate macro insight + container type in parallel; compute layers from actual data
            phase = .analyzingNutrition
            async let insightTask       = generateMacroInsight(for: extraction, productName: productName)
            async let containerTypeTask = generateContainerType(for: extraction, productName: productName)
            let insight       = (try? await insightTask) ?? ""
            let containerType = (try? await containerTypeTask) ?? "box"
            let layers        = computeCompositionLayers(from: extraction, containerType: containerType)

            // Persist
            let scan = ScanModel(
                itemName: productName.isEmpty ? "Unknown Product" : productName,
                ingredients: [],    // nutrition scans have no ingredient list
                category: .nutrition
            )
            let saved = SavedNutritionFacts(from: extraction, insight: insight, layers: layers)
            scan.nutritionFacts = saved
            scan.capturedImagePath = saveCapturedImage(image)
            modelContext.insert(saved)
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
    }

    // MARK: - AI Steps

    private func extractProductName(from rawText: String) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You extract product names from label text. Return only the brand and product name, nothing else."
        )
        let prompt = """
        Find the brand and product name in this label text. Return exactly 'Unknown Product' if not visible.

        LABEL TEXT:
        \(rawText.prefix(1500))
        """
        let result = try await session.respond(to: prompt, generating: NutritionProductName.self)
        return result.content.productName
    }

    private func parseNutritionFacts(from nutritionBlock: String, fullText: String) async throws -> NutritionFactsExtraction {
        let session = LanguageModelSession(
            instructions: """
            You are a precise nutrition label parser. Extract ONLY values that are \
            literally printed on the panel. Return '0' for any field not present. \
            Never infer or calculate values.
            """
        )
        let prompt = """
        Extract nutrition values from this label text. Return plain numbers only — \
        no units, no % signs.

        ── LABEL TEXT ───────────────────────────────────────
        \(nutritionBlock.prefix(2000))

        COLUMN PRIORITY (critical):
        Many labels show TWO columns: "Per serving" and "Per 100g" (or "Per 100mL").
        ALWAYS use the PER SERVING column. NEVER use the per-100g column when a \
        per-serving column exists. The calories line near the top of the panel \
        identifies the per-serving value — all other nutrients come from that same column.

        RULES:
        • Serving size: copy the text exactly as printed (e.g. "1 cup (240 mL)").
        • Calories: the large bold number at the top of the panel for ONE serving.
        • All other fields: the value in the per-serving column, numbers only.
        • Sodium: return the mg number as printed. Only multiply by 1000 if the unit \
          on the label is explicitly 'g' or 'grams' — never multiply an mg value.
        • Micronutrients (Potassium, Calcium, Iron, Vitamin A, C, D): return values \
          exactly as printed. If the label shows percentages only, return '0'. Do not \
          convert between units.
        • "< 1" or "less than 1" → return "0".
        • Field not present → return "0". Serving size not present → return "".
        """
        let result = try await session.respond(to: prompt, generating: NutritionFactsExtraction.self)
        return result.content
    }

    private func generateMacroInsight(for extraction: NutritionFactsExtraction, productName: String) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You are a registered dietitian giving concise, factual macro summaries. Avoid alarmist language."
        )
        let prompt = """
        Give a brief 2–3 sentence macro insight for this product.

        Product: \(productName)
        Per serving: \(extraction.calories) cal | \(extraction.totalFatG)g fat | \
        \(extraction.totalCarbsG)g carbs | \(extraction.proteinG)g protein | \
        \(extraction.sugarG)g sugar | \(extraction.sodiumMg)mg sodium | \(extraction.fiberG)g fiber

        Cover: calories as % of 2,000 cal/day, whether sugar or sodium is notably high/low, one practical note.
        """
        let result = try await session.respond(to: prompt, generating: NutritionInsight.self)
        return result.content.summary
    }

    private func generateContainerType(for extraction: NutritionFactsExtraction, productName: String) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You classify food and drink products into packaging categories."
        )
        let prompt = """
        What container type best represents this product?

        Product: \(productName)
        Per serving: \(extraction.calories) cal | \(extraction.totalFatG)g fat | \
        \(extraction.totalCarbsG)g carbs | \(extraction.proteinG)g protein

        Choose exactly one: 'bottle' (beverages), 'jar' (spreads/pastes), 'bag' (snack packs), 'box' (dry goods and everything else).
        """
        let result = try await session.respond(to: prompt, generating: ContainerTypeResult.self)
        return result.content.containerType
    }

    // Derives composition layers purely from nutrition label data — no AI guessing.
    // For liquids: water = serving volume − macro grams. For dry goods: break carbs into
    // sugar, starch (net carbs), and fiber so they sum correctly without adding water.
    private func computeCompositionLayers(from extraction: NutritionFactsExtraction, containerType: String) -> NutritionLayers {
        let fat       = parseDouble(extraction.totalFatG)
        let totalCarbs = parseDouble(extraction.totalCarbsG)
        let protein   = parseDouble(extraction.proteinG)
        let fiber     = parseDouble(extraction.fiberG)
        let sugar     = parseDouble(extraction.sugarG)
        let starch    = max(0, totalCarbs - sugar - fiber)  // net non-sugar, non-fiber carbs

        var components: [(name: String, grams: Double)] = []

        if containerType == "bottle" {
            let servingMl = parseServingMl(extraction.servingSize)
            let macroTotal = fat + totalCarbs + protein
            let waterG = servingMl > macroTotal ? servingMl - macroTotal : macroTotal * 5.7
            components.append(("Water", waterG))
        }

        if sugar  >= 0.5 { components.append(("Sugar",   sugar)) }
        if starch >= 0.5 { components.append(("Starch",  starch)) }
        if fat    >= 0.5 { components.append(("Fat",     fat)) }
        if protein >= 0.5 { components.append(("Protein", protein)) }
        if fiber  >= 0.5 { components.append(("Fiber",   fiber)) }

        let total = components.reduce(0) { $0 + $1.grams }
        guard total > 0 else {
            return NutritionLayers(containerType: containerType, layerNames: [], layerPercents: [])
        }

        let sorted = components.sorted { $0.grams > $1.grams }
        var percents = sorted.map { Int(($0.grams / total * 100).rounded()) }

        // Fix any rounding drift so sum is exactly 100
        let drift = percents.reduce(0, +) - 100
        if !percents.isEmpty { percents[0] -= drift }

        return NutritionLayers(
            containerType: containerType,
            layerNames: sorted.map { $0.name },
            layerPercents: percents.map { String($0) }
        )
    }

    private func parseDouble(_ s: String) -> Double {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let d = Double(t) { return d }
        let n = t.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        return Double(n) ?? 0
    }

    private func parseServingMl(_ serving: String) -> Double {
        let s = serving.lowercased()
        if let v = extractLeadingNumber(before: "ml", in: s), v > 0 { return v }
        let noMg = s.replacingOccurrences(of: "mg", with: "  ")
        if let v = extractLeadingNumber(before: "g", in: noMg), v > 0 { return v }
        return 0
    }

    private func extractLeadingNumber(before unit: String, in text: String) -> Double? {
        guard let idx = text.range(of: unit)?.lowerBound else { return nil }
        let before = String(text[..<idx])
        let parts = before.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
        guard let numStr = parts.last(where: { !$0.isEmpty }) else { return nil }
        return Double(numStr)
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

    // MARK: - Validation

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
}
