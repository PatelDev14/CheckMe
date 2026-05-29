//
//  TextRecognization.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Vision
import UIKit

// Wraps Vision's VNRecognizeTextRequest into a clean async interface.
// After OCR, applies heuristic extraction to isolate the ingredient block
// from surrounding label text (net weight, marketing copy, barcode data).

struct TextRecognizer {

    // MARK: - Image Preprocessing

    /// Contrast + greyscale + sharpen pass.
    /// Good for coloured packaging where text and background have similar tones.
    private static func preprocessImage(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)
        var current = ciImage

        if let f = CIFilter(name: "CIExposureAdjust") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.3, forKey: kCIInputEVKey)
            if let out = f.outputImage { current = out }
        }
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(1.4, forKey: kCIInputContrastKey)
            f.setValue(0.0, forKey: kCIInputBrightnessKey)
            f.setValue(0.0, forKey: kCIInputSaturationKey)
            if let out = f.outputImage { current = out }
        }
        if let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.8, forKey: kCIInputRadiusKey)
            f.setValue(1.0, forKey: kCIInputIntensityKey)
            if let out = f.outputImage { current = out }
        }

        let ctx = CIContext()
        return ctx.createCGImage(current, from: current.extent) ?? cgImage
    }

    /// Hard binarization pass — converts to high-contrast greyscale.
    /// Best for dark or coloured packaging where the contrast pass still leaves
    /// too much colour noise for Vision to parse cleanly.
    private static func binarizeImage(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)
        var current = ciImage

        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.0, forKey: kCIInputSaturationKey)
            f.setValue(1.8, forKey: kCIInputContrastKey)
            if let out = f.outputImage { current = out }
        }
        if let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.5, forKey: kCIInputRadiusKey)
            f.setValue(1.5, forKey: kCIInputIntensityKey)
            if let out = f.outputImage { current = out }
        }

        let ctx = CIContext()
        return ctx.createCGImage(current, from: current.extent) ?? cgImage
    }

    /// 2× upscaling pass — dramatically improves recognition of tiny ingredient
    /// text on narrow or small packages (e.g. lip balm, seasoning sachets).
    private static func upscaleImage(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)
        var current = ciImage

        if let f = CIFilter(name: "CILanczosScaleTransform") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(2.0, forKey: kCIInputScaleKey)
            f.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let out = f.outputImage { current = out }
        }
        if let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(current, forKey: kCIInputImageKey)
            f.setValue(0.6, forKey: kCIInputRadiusKey)
            f.setValue(0.8, forKey: kCIInputIntensityKey)
            if let out = f.outputImage { current = out }
        }

        let ctx = CIContext()
        return ctx.createCGImage(current, from: current.extent) ?? cgImage
    }

    // MARK: - Image Normalization

    /// Redraws the image into a normalised .up orientation so Vision always
    /// receives pixels in the expected order regardless of how the camera stored them.
    private static func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalised = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalised ?? image
    }

    // MARK: - OCR

    /// Runs four OCR passes on the image and returns the result that extracted the
    /// most text.  The four passes cover the widest range of real-world packaging:
    ///
    ///   Pass 1 — raw      : clear white-background ingredient panels
    ///   Pass 2 — boosted  : coloured / glossy packaging (contrast + greyscale)
    ///   Pass 3 — binary   : dark backgrounds (hard binarization)
    ///   Pass 4 — upscaled : tiny text on small/narrow packages
    ///
    /// `preprocess: false` skips passes 2–4 and returns only the raw result.
    /// Used by the retry path in IngredientsViewModel so processing artefacts
    /// from a failed first attempt do not compound.
    static func recognizeText(from image: UIImage, preprocess: Bool = true) async throws -> String {
        let normalised = normalizeImageOrientation(image)
        guard let cgImage = normalised.cgImage else { throw RecognitionError.invalidImage }

        let rawText = (try? await singlePass(cgImage)) ?? ""

        guard preprocess else { return rawText }

        async let boostTask   = singlePass(preprocessImage(cgImage))
        async let binaryTask  = singlePass(binarizeImage(cgImage))
        async let upscaleTask = singlePass(upscaleImage(cgImage))

        let boostText   = (try? await boostTask)   ?? ""
        let binaryText  = (try? await binaryTask)  ?? ""
        let upscaleText = (try? await upscaleTask) ?? ""

        return [rawText, boostText, binaryText, upscaleText]
            .max(by: { $0.count < $1.count }) ?? rawText
    }

    /// Single Vision OCR pass on a pre-prepared CGImage.
    private static func singlePass(_ cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                continuation.resume(returning: Self.reconstructText(from: observations))
            }

            request.recognitionLevel              = .accurate
            request.usesLanguageCorrection        = true
            request.recognitionLanguages          = ["en-US", "fr-CA", "es-MX"]
            request.automaticallyDetectsLanguage  = true
            request.minimumTextHeight             = 0.008

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do    { try handler.perform([request]) }
            catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Text Reconstruction

    /// Groups Vision observations into horizontal rows, then reads each row left-to-right.
    /// Row height threshold is computed adaptively from the median observation height so the
    /// grouping works correctly for both tiny 6-pt text and large 24-pt headings.
    private static func reconstructText(from observations: [VNRecognizedTextObservation]) -> String {
        guard !observations.isEmpty else { return "" }

        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        let heights = sorted.map { $0.boundingBox.height }.sorted()
        let medianHeight = heights[heights.count / 2]
        let rowThreshold = medianHeight * 0.6

        var rows: [[VNRecognizedTextObservation]] = []
        var currentRow: [VNRecognizedTextObservation] = []

        for obs in sorted {
            let midY = obs.boundingBox.midY
            if let anchorY = currentRow.first.map({ $0.boundingBox.midY }),
               abs(midY - anchorY) <= rowThreshold {
                currentRow.append(obs)
            } else {
                if !currentRow.isEmpty { rows.append(currentRow) }
                currentRow = [obs]
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        let lines = rows.map { row -> String in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
               .compactMap { obs -> String? in
                   obs.topCandidates(3)
                      .first { $0.confidence > 0.2 }?
                      .string
               }
               .joined(separator: " ")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Ingredient Block Extraction

    /// Isolates the ingredient block from the full OCR text.
    ///
    /// Strategy 1 — header-based line walk: finds the "Ingredients:" header then reads
    ///   line by line, stopping the moment it hits a foreign-language section or a
    ///   terminator keyword.  More precise than a plain string slice.
    ///
    /// Strategy 2 — comma density: no header visible; return the paragraph that has
    ///   the most commas (ingredient lists are far denser in commas than any other section).
    ///
    /// NOTE: "Contains: Wheat, Milk" is an allergen declaration — NOT an ingredient
    /// header — so it is intentionally NOT used as a Strategy 2 fallback.
    ///
    /// Every candidate is passed through cleanAndFormat() before being returned.
    static func extractIngredientBlock(from rawText: String) -> String {
        let lines = rawText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let block = findBlockWithIngredientHeader(in: lines), block.count > 10 {
            return cleanAndFormat(String(block.prefix(3000)))
        }

        if let block = longestCommaSeparatedBlock(in: rawText), block.count > 30 {
            return cleanAndFormat(String(block.prefix(3000)))
        }

        return cleanAndFormat(String(rawText.prefix(3000)))
    }

    // MARK: - Header-Based Line Walking

    private static let ingredientHeaders: [String] = [
        // English
        "ingredients:", "ingredient:", "ingredients :", "ingredient :",
        "ingredients", "ingredient",
        // OCR "I" misread as "l"
        "lngredients:", "lngredients",
        // Personal care / INCI
        "inci:", "ingredients/inci:", "ingredients (inci):",
        // Spanish
        "ingredientes:", "ingrediente:", "ingredientes", "ingrediente",
        // Other common variants
        "ingredient list:", "contains the following ingredients:",
        "made with:", "made from:",
        "composition:", "composé de:", "composé d':",
        "formula:",
    ]

    /// Strategy 1: walk line-by-line after an ingredients-style header.
    private static func findBlockWithIngredientHeader(in lines: [String]) -> String? {
        guard let headerIndex = lines.firstIndex(where: { line in
            let lower = line.lowercased()
            // Must contain one of our known headers AND must not itself be in a foreign section
            return ingredientHeaders.contains(where: { lower.contains($0) })
                && !isForeignLanguage(line)
        }) else { return nil }

        return extractTextAfterHeader(
            from: lines,
            startingAt: headerIndex,
            headerLine: lines[headerIndex]
        )
    }

    /// Walks lines starting at the header, accumulating ingredient text and stopping
    /// as soon as a terminator or foreign-language line is encountered.
    private static func extractTextAfterHeader(
        from lines: [String],
        startingAt headerIndex: Int,
        headerLine: String
    ) -> String? {
        var result = ""

        // Capture any text that appears after the colon on the header line itself
        if let colonRange = headerLine.range(of: ":") {
            let afterColon = String(headerLine[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterColon.isEmpty {
                result = stopAtTerminators(afterColon)
            }
        }

        // Walk every line that follows the header
        if headerIndex + 1 < lines.count {
            for line in lines[(headerIndex + 1)...] {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                // Stop as soon as we hit a French / bilingual section
                if isForeignLanguage(trimmed) { break }
                // Stop on allergen / nutrition / distribution copy
                if isTerminatorLine(trimmed) { break }

                if !result.isEmpty && !result.hasSuffix(",") && !result.hasSuffix(" ") {
                    result += " "
                }

                let safe = stopAtTerminators(trimmed)
                result += safe

                // If stopAtTerminators trimmed the line, a terminator was mid-line — stop here
                if safe.count < trimmed.count { break }
            }
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - Terminator & Language Helpers

    /// Returns true if the line appears to be French (Canadian bilingual labels).
    /// When we hit this, we've crossed into the French duplicate — stop collecting.
    private static func isForeignLanguage(_ line: String) -> Bool {
        let lower = line.lowercased()
        let frenchKeywords = [
            "ingrédients", "ingrédient", "contient", "peut contenir",
            "fabriqué", "à base de", "farine de blé", "sans gluten",
            "valeur nutritive", "par portion", "matière grasse",
        ]
        return frenchKeywords.contains { lower.contains($0) }
    }

    /// Returns true if the line marks the start of a non-ingredient section.
    private static func isTerminatorLine(_ line: String) -> Bool {
        let lower = line.lowercased()

        let terminators = [
            "may contain", "allergen", "nutrition facts", "nutrition information",
            "serving size", "servings per", "calories", "per serving",
            "manufactured by", "distributed by", "produced by", "imported by",
            "packaged by", "prepared by", "packed by",
            "best before", "meilleur avant", "use by", "best by",
            "net weight", "net wt", "storage", "keep refrigerated",
            "store in", "warning", "caution", "upc", "www.",
        ]

        if terminators.contains(where: { lower.contains($0) }) { return true }

        // "Contains: Wheat, Milk" at the START of a line is an allergen declaration — stop here.
        // We must NOT check for "contains" mid-line because ingredient lists routinely have
        // inline text like "Flour (contains wheat)" and we don't want to cut those short.
        if lower.hasPrefix("contains:") || lower.hasPrefix("contains ") { return true }

        // NOTE: We intentionally do NOT apply a sentence-boundary heuristic (period + uppercase)
        // here. Food labels frequently list ingredients that end with a period or contain
        // multi-word entries like "Natural Flavour. Citric Acid." which would cause false stops.

        return false
    }

    /// Truncates text at the first terminator keyword found within it.
    /// Returns the full string unchanged if no terminator is present.
    ///
    /// IMPORTANT: "contains" is intentionally NOT in this list.
    /// Ingredient labels routinely include inline text like "Flour (contains wheat)"
    /// — if we cut at "contains" here we lose everything after that parenthetical.
    /// "Contains:" as a standalone allergen section is caught by isTerminatorLine()
    /// before this function is ever called on that line.
    private static func stopAtTerminators(_ text: String) -> String {
        let lower = text.lowercased()

        let terminators = [
            "may contain:", "may contain ", "allergen", "nutrition facts",
            "nutrition information", "nutritional", "serving size", "calories",
            "manufactured by", "distributed by", "produced by", "best before",
            "use by", "net weight", "net wt", "storage", "warning", "upc", "www.",
        ]

        var earliestIdx = text.count
        for terminator in terminators {
            if let range = lower.range(of: terminator) {
                let idx = lower.distance(from: lower.startIndex, to: range.lowerBound)
                earliestIdx = min(earliestIdx, idx)
            }
        }

        if earliestIdx < text.count {
            return String(text.prefix(earliestIdx))
                .trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
        }
        return text
    }

    // MARK: - Text Cleaning

    /// Normalises an extracted ingredient block before handing it to the AI:
    ///   • strips header words that leaked into the body
    ///   • removes parenthetical allergen statements "(contains soy)"
    ///   • removes stray percentage values
    ///   • converts bullet characters and semicolons to commas
    ///   • collapses runs of whitespace and duplicate commas
    private static func cleanAndFormat(_ text: String) -> String {
        var cleaned = text

        // Strip header words that OCR sometimes captures at the start of the block
        let headersToStrip = [
            "ingredients:", "ingredient:", "ingredients :", "ingredient :",
            "ingredients", "ingredient",
            "lngredients:", "lngredients",
            "inci:", "ingredientes:", "ingrediente:",
            "made with:", "made from:", "contains:",
            "composition:", "formula:",
        ]
        for header in headersToStrip {
            cleaned = cleaned.replacingOccurrences(
                of: header, with: "", options: .caseInsensitive
            )
        }

        // Remove parenthetical allergen statements like "(contains soy, milk)"
        cleaned = cleaned.replacingOccurrences(
            of: #"\(contains [^)]+\)"#,
            with: "",
            options: .regularExpression
        )

        // Remove percentage figures (e.g. "2%", "0.5%")
        cleaned = cleaned.replacingOccurrences(
            of: #"\d+\.?\d*\s*%"#,
            with: "",
            options: .regularExpression
        )

        // Convert bullet characters to commas so the AI sees a standard list
        for bullet in ["•", "●", "·", "◦", "▪"] {
            cleaned = cleaned.replacingOccurrences(of: bullet, with: ",")
        }

        // Semicolons → commas (some labels use semicolons between ingredients)
        cleaned = cleaned.replacingOccurrences(of: ";", with: ",")

        // Collapse stray colons left after header stripping
        cleaned = cleaned.replacingOccurrences(of: ":", with: "")

        // Collapse multiple spaces / newlines into a single space
        cleaned = cleaned.replacingOccurrences(
            of: #"[\s]+"#, with: " ", options: .regularExpression
        )

        // Normalise comma spacing: strip space before comma, one space after
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*,\s*"#, with: ", ", options: .regularExpression
        )

        // Collapse sequences of commas (e.g. ",," → ",")
        cleaned = cleaned.replacingOccurrences(
            of: #",+"#, with: ",", options: .regularExpression
        )

        // Remove leading / trailing commas and spaces
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ", "))

        return cleaned
    }

    // MARK: - Comma-Density Fallback

    /// Splits `text` into paragraphs and returns the one that contains the most
    /// comma-separated tokens — a strong signal for an ingredient list.
    private static func longestCommaSeparatedBlock(in text: String) -> String? {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        return paragraphs.max(by: {
            $0.components(separatedBy: ",").count < $1.components(separatedBy: ",").count
        })
    }

    // MARK: - Nutrition Block Extraction

    /// Isolates the Nutrition Facts panel from the full OCR text.
    static func extractNutritionBlock(from rawText: String) -> String {
        let lower = rawText.lowercased()

        let headers: [String] = [
            "nutrition facts", "valeur nutritive",
            "nutrition information", "informations nutritionnelles",
            "nutritional information", "nutritional facts",
        ]

        let cutMarkers: [String] = [
            "ingredients:", "ingredient:", "ingredients :", "ingredient :",
            "ingredients\n", "ingredient\n",
            "made with:", "made from:",
            "ingrédients:", "ingrédient:", "ingrédients :", "ingrédient :",
            "ingrédients\n", "ingrédient\n",
            "composition:", "composé de:",
            "distributed by", "manufactured by", "produced by", "packaged by",
            "best before", "meilleur avant",
            "upc", "www.", "visit us",
        ]

        var bestBlock = ""

        for header in headers {
            guard let range = lower.range(of: header) else { continue }
            let contentStart = lower.distance(from: lower.startIndex, to: range.lowerBound)
            guard contentStart < rawText.count else { continue }
            let startIndex = rawText.index(rawText.startIndex, offsetBy: contentStart)
            let snippet = String(rawText[startIndex...])

            let snipLower = snippet.lowercased()
            var cutIndex = snippet.endIndex
            for marker in cutMarkers {
                if let r = snipLower.range(of: marker), r.lowerBound < cutIndex {
                    cutIndex = r.lowerBound
                }
            }

            let candidate = String(snippet[..<cutIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if candidate.count > 10 && candidate.count > bestBlock.count {
                bestBlock = candidate
            }
        }

        if !bestBlock.isEmpty { return String(bestBlock.prefix(2000)) }

        let nutritionSignals = [
            "calorie", "total fat", "saturated", "sodium", "carbohydrate", "protein",
            "dietary fiber", "total sugar", "cholesterol", "trans fat",
            "matière grasse", "glucides", "protéine", "fibres",
        ]
        if nutritionSignals.filter({ lower.contains($0) }).count >= 2 {
            return String(rawText.prefix(2000))
        }

        return ""
    }

    // MARK: - Quality Check

    /// Returns true if the OCR result looks like it contains an ingredient list.
    /// Covers food labels AND personal care / cosmetic product labels.
    static func looksLikeIngredientLabel(_ text: String) -> Bool {
        let lower = text.lowercased()

        let foodSignals = [
            "ingredient", "contains", "water", "sugar", "salt", "flour",
            "sodium", "extract", "natural flavour", "artificial", "starch",
            "modified", "wheat", "corn", "soy", "milk", "egg",
        ]
        let skinSignals = [
            "aqua", "glycerin", "alcohol", "parfum", "fragrance",
            "cetyl", "stearyl", "dimethicone", "paraben", "tocopherol",
            "panthenol", "niacinamide", "retinol", "hyaluronic",
            "sodium laureth", "cocamidopropyl", "phenoxyethanol",
        ]

        let foodMatches = foodSignals.filter { lower.contains($0) }.count
        let skinMatches = skinSignals.filter { lower.contains($0) }.count

        return foodMatches >= 2 || skinMatches >= 2
    }
}

// MARK: - Errors

enum RecognitionError: LocalizedError {
    case invalidImage
    case noTextFound
    case notAnIngredientLabel
    case notANutritionLabel

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image."
        case .noTextFound:
            return "No text was detected. Try better lighting or move closer."
        case .notAnIngredientLabel:
            return "This doesn't look like an ingredient label. Try scanning a different part of the package."
        case .notANutritionLabel:
            return "No Nutrition Facts panel detected. Point the camera directly at the nutrition label."
        }
    }
}
