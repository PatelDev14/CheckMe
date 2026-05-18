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

    /// Enhances image contrast and brightness to improve OCR recognition.
    /// Vision framework sometimes struggles with images that have low contrast or unusual lighting.
    /// This preprocessing normalizes the image to make text more legible.
    private static func preprocessImage(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)

        // Step 1: Normalize exposure and increase contrast using CIExposureAdjust + CIColorControls
        var currentImage = ciImage

        // Adjust exposure to normalize brightness
        if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(currentImage, forKey: kCIInputImageKey)
            exposureFilter.setValue(0.2, forKey: kCIInputEVKey)
            if let exposureOutput = exposureFilter.outputImage {
                currentImage = exposureOutput
            }
        }

        // Increase contrast and saturation to make text stand out
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(currentImage, forKey: kCIInputImageKey)
            colorFilter.setValue(1.5, forKey: kCIInputContrastKey)  // Higher contrast for text clarity
            colorFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(1.0, forKey: kCIInputSaturationKey)
            if let colorOutput = colorFilter.outputImage {
                currentImage = colorOutput
            }
        }

        // Step 2: Apply sharpening to make text edges crisp
        if let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
            sharpenFilter.setValue(currentImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(1.0, forKey: kCIInputRadiusKey)  // Moderate radius
            sharpenFilter.setValue(1.2, forKey: kCIInputIntensityKey)  // Strong sharpening
            if let sharpenOutput = sharpenFilter.outputImage {
                currentImage = sharpenOutput
            }
        }

        // Render the processed CIImage back to CGImage
        let context = CIContext()
        let extent = currentImage.extent
        if let renderedCGImage = context.createCGImage(currentImage, from: extent) {
            return renderedCGImage
        }

        return cgImage
    }

    // MARK: - Image Normalization

    /// Corrects image orientation if needed, ensuring Vision framework sees the image correctly.
    /// The camera may return images with various orientations, which can affect OCR accuracy.
    private static func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        // If image is already in correct orientation, return as-is
        if image.imageOrientation == .up {
            return image
        }

        // Redraw the image with correct orientation
        let rect = CGRect(origin: .zero, size: image.size)
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }

    // MARK: - OCR

    /// Returns the full OCR text from the image, lines sorted top-to-bottom.
    ///
    /// `preprocess`: apply contrast/sharpening before OCR. Helps with ingredient labels
    /// on coloured packaging but HURTS nutrition panels — black text on white is already
    /// high-contrast and aggressive sharpening distorts digits ("35" → "3.5").
    static func recognizeText(from image: UIImage, preprocess: Bool = true) async throws -> String {
        let normalizedImage = normalizeImageOrientation(image)
        guard let cgImage = normalizedImage.cgImage else { throw RecognitionError.invalidImage }

        let cgToUse = preprocess ? preprocessImage(cgImage) : cgImage

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = Self.reconstructText(from: observations)
                print("[OCR] \(observations.count) observations → \(text.count) chars\(preprocess ? " (preprocessed)" : "")")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "fr-CA"]
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgToUse, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Text Reconstruction

    /// Groups Vision observations into horizontal rows, then reads each row left-to-right.
    /// This produces more natural reading order on labels that use multiple columns,
    /// which is common on cans, bottles, and narrow packages.
    private static func reconstructText(from observations: [VNRecognizedTextObservation]) -> String {
        guard !observations.isEmpty else { return "" }

        // Sort all observations top-to-bottom (Vision coords: minY = bottom, maxY = top)
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        // Group into rows: two observations belong to the same row if their vertical
        // midpoints are within 2% of the page height of each other.
        let rowThreshold: CGFloat = 0.02
        var rows: [[VNRecognizedTextObservation]] = []
        var currentRow: [VNRecognizedTextObservation] = []

        for obs in sorted {
            let midY = obs.boundingBox.midY
            if let firstMidY = currentRow.first.map({ $0.boundingBox.midY }),
               abs(midY - firstMidY) <= rowThreshold {
                currentRow.append(obs)
            } else {
                if !currentRow.isEmpty { rows.append(currentRow) }
                currentRow = [obs]
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        // Within each row, sort left-to-right by minX
        let lines = rows.map { row -> String in
            let leftToRight = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            return leftToRight
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Ingredient Block Extraction

    /// Isolates the ingredient block from the full OCR text.
    ///
    /// Strategy:
    /// 1. Scan every known header variant (English + French, colon/no-colon, upper/lower case).
    /// 2. For each match, cut the snippet at the first major section boundary that follows.
    /// 3. Return the longest valid block found — this handles bilingual labels where the
    ///    English block may be shorter than the French, or vice-versa.
    /// 4. Fall back to the entire raw text so the AI always has something to work with.
    static func extractIngredientBlock(from rawText: String) -> String {
        let lower = rawText.lowercased()

        // All recognised header patterns, ordered most-specific first.
        // Lowercase only — we compare against `lower` not `rawText`.
        let headers: [String] = [
            // English — with colon
            "ingredients:", "ingredient:", "ingredients :", "ingredient :",
            // English — newline-terminated (e.g. "INGREDIENTS\nWater, Sugar…")
            "ingredients\n", "ingredient\n",
            // French — with colon
            "ingrédients:", "ingrédient:", "ingrédients :", "ingrédient :",
            "ingrédients\n", "ingrédient\n",
            // Alternate headers found on some labels
            "made with:", "made from:", "contains the following ingredients:",
            "composition:", "composé de:", "composé d':"
        ]

        // Section-boundary markers: text that signals the ingredient list has ended.
        // "contains:" / "may contain:" are allergen statements, NOT ingredient headers here.
        // "and less than" is intentionally absent — it is PART of the ingredient list.
        let cutMarkers: [String] = [
            // Nutrition panel headers (English + French variants) — always a hard stop
            "nutrition facts", "valeur nutritive", "nutrition information",
            "informations nutritionnelles", "tableau de la valeur nutritive",
            "nutritional information", "nutritional facts",
            "vitamins and minerals", "vitamines et minéraux",
            "% daily value", "% valeur quotidienne",
            "serving size", "servings per container",
            "per serving", "par portion",
            "calories",                           // Nutrition panel always starts here
            // French ingredient header signals the bilingual second block — stop before it
            "ingrédients:", "ingrédient:", "ingrédients :", "ingrédient :",
            "ingrédients\n", "ingrédient\n",
            "allergen information", "allergen statement", "allergen advice",
            "may contain", "peut contenir",       // Allergen warnings
            "contains: ",                         // Allergen "Contains: milk, wheat"
            "distributed by", "manufactured by", "produced by", "imported by",
            "packed by", "prepared by", "packaged by",
            "best before", "meilleur avant",
            "keep refrigerated", "store in", "refrigerate after",
            "upc", "www.", "visit us", "call us",  // Back-of-pack boilerplate
        ]

        // Collect all candidate blocks and return the longest non-trivial one.
        var bestBlock = ""

        for header in headers {
            guard let headerRange = lower.range(of: header) else { continue }

            // Start of ingredient text is right after the header keyword
            let contentStart = lower.distance(from: lower.startIndex, to: headerRange.upperBound)
            guard contentStart < rawText.count else { continue }
            let startIndex = rawText.index(rawText.startIndex, offsetBy: contentStart)
            let snippet = String(rawText[startIndex...])

            // Find the earliest section boundary after the header
            let snipLower = snippet.lowercased()
            var cutIndex = snippet.endIndex
            for marker in cutMarkers {
                if let r = snipLower.range(of: marker) {
                    if r.lowerBound < cutIndex { cutIndex = r.lowerBound }
                }
            }

            let candidate = String(snippet[..<cutIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Only accept blocks that look substantial (> 10 chars avoids empty matches)
            if candidate.count > 10 && candidate.count > bestBlock.count {
                bestBlock = candidate
            }
        }

        if !bestBlock.isEmpty {
            // 3 000-char cap — enough for the longest real-world ingredient list
            return String(bestBlock.prefix(3000))
        }

        // No header found — hand the full text to the AI and let it figure it out
        print("[OCR] No ingredient header found — passing full label text to AI")
        return String(rawText.prefix(3000))
    }

    // MARK: - Nutrition Block Extraction

    /// Isolates the Nutrition Facts panel from the full OCR text.
    /// Mirrors the same strategy as `extractIngredientBlock` but in reverse:
    /// starts at the nutrition header and cuts when the ingredient list begins.
    static func extractNutritionBlock(from rawText: String) -> String {
        let lower = rawText.lowercased()

        let headers: [String] = [
            "nutrition facts", "valeur nutritive",
            "nutrition information", "informations nutritionnelles",
            "nutritional information", "nutritional facts"
        ]

        // Cut when the ingredient section or unrelated boilerplate begins
        let cutMarkers: [String] = [
            // English ingredient headers — stop before the ingredient list
            "ingredients:", "ingredient:", "ingredients :", "ingredient :",
            "ingredients\n", "ingredient\n",
            "made with:", "made from:",
            // French ingredient headers — stop before the French block on bilingual labels
            "ingrédients:", "ingrédient:", "ingrédients :", "ingrédient :",
            "ingrédients\n", "ingrédient\n",
            "composition:", "composé de:",
            // Boilerplate
            "distributed by", "manufactured by", "produced by", "packaged by",
            "best before", "meilleur avant",
            "upc", "www.", "visit us"
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

        if !bestBlock.isEmpty {
            return String(bestBlock.prefix(2000))
        }

        // No header detected — user may have cropped the image so the "Nutrition Facts"
        // title is outside the frame, leaving only the data rows. Fall back to full text
        // if it looks like a nutrition panel (contains common nutrient keywords).
        let nutritionSignals = [
            "calorie", "total fat", "saturated", "sodium", "carbohydrate", "protein",
            "dietary fiber", "total sugar", "cholesterol", "trans fat",
            "matière grasse", "glucides", "protéine", "fibres"
        ]
        let signalMatches = nutritionSignals.filter { lower.contains($0) }.count
        if signalMatches >= 2 {
            print("[OCR] No nutrition header found but \(signalMatches) panel signals detected — using full text")
            return String(rawText.prefix(2000))
        }

        return ""
    }

    // MARK: - Quality Check

    /// Returns true if the OCR result looks like it contains an ingredient list.
    /// Used to gate the AI call and provide better user-facing errors.
    static func looksLikeIngredientLabel(_ text: String) -> Bool {
        let lower = text.lowercased()
        let signals = ["ingredient", "contains", "water", "sugar", "salt", "flour",
                       "sodium", "extract", "natural flavour", "artificial"]
        let matchCount = signals.filter { lower.contains($0) }.count
        return matchCount >= 2
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
        case .invalidImage:         return "Could not process the image."
        case .noTextFound:          return "No text was detected. Try better lighting or move closer."
        case .notAnIngredientLabel: return "This doesn't look like an ingredient label. Try scanning a different part of the package."
        case .notANutritionLabel:   return "No Nutrition Facts panel detected. Point the camera directly at the nutrition label."
        }
    }
}
