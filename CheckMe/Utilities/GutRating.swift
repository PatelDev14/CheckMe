import SwiftUI

// MARK: - Gut Rating Helper

/// Parses an AI gut-prediction string (e.g. "Gut Friendly — ...") to extract a
/// rating descriptor for color/icon/label use across the app (ingredient list,
/// scan history, and the diary timeline).
struct GutRating {
    let label: String
    let color: Color
    let icon: String

    init(from prediction: String) {
        let lower = prediction.lowercased()
        if lower.contains("gut friendly") {
            label = "Gut Friendly"; color = .green; icon = "checkmark.seal.fill"
        } else if lower.contains("moderate risk") {
            label = "Moderate Risk"; color = .orange; icon = "exclamationmark.triangle.fill"
        } else if lower.contains("high risk") {
            label = "High Risk"; color = .red; icon = "xmark.octagon.fill"
        } else {
            label = "Unknown"; color = .gray; icon = "questionmark.circle.fill"
        }
    }
}
