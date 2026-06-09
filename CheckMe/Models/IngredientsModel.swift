import Foundation
import FoundationModels
import SwiftData

// MARK: - Cached per-ingredient AI summary

@Model
class IngredientsModel {
    var name: String
    var explanation: String
    var digestion: String
    var digestiveFeel: String

    // Rich fields — populated by updated AI analysis.
    // Older cached records will have empty keyFacts; the ViewModel detects this
    // and forces a re-analysis so users always get the full visual experience.
    var safetyRating: String    = "Generally Safe"  // "Generally Safe" | "Monitor" | "Use Caution" | "Avoid"
    var origin: String          = "Natural"          // "Natural" | "Semi-Synthetic" | "Synthetic"
    var processingSpeed: String = "Moderate"         // "Fast" | "Moderate" | "Slow"
    var keyFacts: [String]      = []                 // exactly 3 short scannable facts

    init(name: String, explanation: String, digestion: String, digestiveFeel: String,
         safetyRating: String = "Generally Safe", origin: String = "Natural",
         processingSpeed: String = "Moderate", keyFacts: [String] = []) {
        self.name           = name
        self.explanation    = explanation
        self.digestion      = digestion
        self.digestiveFeel  = digestiveFeel
        self.safetyRating   = safetyRating
        self.origin         = origin
        self.processingSpeed = processingSpeed
        self.keyFacts       = keyFacts
    }
}

@Generable
struct IngredientSummary {
    @Guide(description: "Explain what this ingredient is in plain, accessible language (2-3 sentences).")
    let explanation: String

    @Guide(description: "Describe how the body digests and processes this ingredient (2 sentences).")
    let digestion: String

    @Guide(description: """
        Describe the typical physical or digestive experience after consuming this ingredient \
        (1-2 sentences). Be specific — e.g. 'quick energy boost', \
        'may cause bloating in sensitive individuals', 'gentle on most stomachs'.
        """)
    let digestiveFeel: String

    @Guide(description: """
        Overall safety rating for a general population. \
        Return EXACTLY one of these four values: \
        'Generally Safe' — widely consumed, no notable concerns for most people; \
        'Monitor' — fine for most but worth watching in large quantities; \
        'Use Caution' — associated with specific health concerns or sensitivities; \
        'Avoid' — strongly linked to adverse health effects for most people.
        """)
    let safetyRating: String

    @Guide(description: """
        Ingredient origin. Return EXACTLY one of: \
        'Natural' — derived directly from plants, animals, or minerals with minimal processing; \
        'Semi-Synthetic' — natural source but chemically modified; \
        'Synthetic' — manufactured through chemical synthesis with no natural equivalent.
        """)
    let origin: String

    @Guide(description: """
        How quickly the human body processes this ingredient. \
        Return EXACTLY one of: 'Fast' (digested within minutes-to-an-hour, e.g. simple sugars, caffeine); \
        'Moderate' (1–4 hours, e.g. proteins, starches); \
        'Slow' (4+ hours or passes through largely undigested, e.g. fats, fiber).
        """)
    let processingSpeed: String

    @Guide(description: """
        Exactly 3 short, scannable facts about this ingredient. \
        Each fact must be 6–12 words. \
        Focus on practical consumer knowledge: common uses, notable properties, things to know. \
        Example facts: 'Preserves food by inhibiting bacterial growth', \
        'Naturally derived from sugar beet or cane', 'Can trigger headaches in sensitive individuals'.
        """)
    let keyFacts: [String]
}
