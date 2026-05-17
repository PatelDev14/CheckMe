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
    /// Includes comprehensive logging for debugging recognition failures.
    static func recognizeText(from image: UIImage) async throws -> String {
        // First, normalize the image orientation
        let normalizedImage = normalizeImageOrientation(image)

        guard let cgImage = normalizedImage.cgImage else {
            throw RecognitionError.invalidImage
        }

        // Log image metadata for debugging
        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        let imageScale = normalizedImage.scale
        let imageOrientation = normalizedImage.imageOrientation
        let effectiveWidth = Int(CGFloat(imageWidth) / imageScale)
        let effectiveHeight = Int(CGFloat(imageHeight) / imageScale)

        print("[OCR Debug] Image metadata:")
        print("  - Dimensions: \(imageWidth) × \(imageHeight) px")
        print("  - Scale: \(imageScale)x")
        print("  - Orientation: \(imageOrientation.rawValue)")
        print("  - Effective size: \(effectiveWidth) × \(effectiveHeight)")

        // Check if image is large enough for OCR (Vision needs reasonable resolution)
        let minDimension = 200
        if effectiveWidth < minDimension || effectiveHeight < minDimension {
            print("[OCR Debug] Warning: Image might be too small for OCR (recommended >= \(minDimension) in both dimensions)")
        }

        // Preprocess the image to enhance contrast and sharpness
        let processedCGImage = preprocessImage(cgImage)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    print("[OCR Debug] Vision request failed: \(error.localizedDescription)")
                    print("[OCR Debug] Error code: \((error as NSError).code)")
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []

                print("[OCR Debug] Vision found \(observations.count) text observations")

                if observations.isEmpty {
                    print("[OCR Debug] ⚠️  No text observations detected — this could mean:")
                    print("   - Image contains no readable text")
                    print("   - Text is too small or unclear")
                    print("   - Image format incompatibility")
                    print("   - Preprocessing removed too much information")
                }

                // Reconstruct reading order: Vision's coordinate origin is bottom-left.
                // Group observations into horizontal "rows" (same vertical band), then
                // sort each row left-to-right so two-column labels are read correctly.
                // Rows within 2% of page height of each other are treated as the same line.
                let text = Self.reconstructText(from: observations)

                print("[OCR Debug] Extracted text length: \(text.count) characters")
                if !text.isEmpty {
                    print("[OCR Debug] First 150 chars: \(String(text.prefix(150)))")
                } else {
                    print("[OCR Debug] ⚠️  Text extraction resulted in empty string despite observations")
                }

                continuation.resume(returning: text)
            }

            // Use accurate recognition for better results with labels
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "fr-CA"]  // bilingual labels are common

            // Attempt to auto-detect text if standard approach fails
            request.automaticallyDetectsLanguage = true

            // Use the preprocessed image with proper orientation
            let handler = VNImageRequestHandler(
                cgImage: processedCGImage,
                orientation: .up,  // Image is already normalized to .up orientation
                options: [:]
            )

            do {
                print("[OCR Debug] Starting Vision OCR request with processed image...")
                print("[OCR Debug] Image size: \(processedCGImage.width) × \(processedCGImage.height)")
                try handler.perform([request])
                print("[OCR Debug] Vision request completed successfully")
            } catch {
                print("[OCR Debug] Failed to perform Vision request: \(error.localizedDescription)")
                print("[OCR Debug] Handler error code: \((error as NSError).code)")
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
            "nutrition facts", "valeur nutritive", "nutrition information",
            "informations nutritionnelles",
            "vitamins and minerals", "vitamines et minéraux",
            "% daily value", "% valeur quotidienne",
            "serving size", "servings per container",
            "per serving", "par portion",
            "calories",                           // Nutrition panel always starts here
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

    var errorDescription: String? {
        switch self {
        case .invalidImage:          return "Could not process the image."
        case .noTextFound:           return "No text was detected. Try better lighting or move closer."
        case .notAnIngredientLabel:  return "This doesn't look like an ingredient label. Try scanning a different part of the package."
        }
    }
}
