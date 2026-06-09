import Foundation
import FoundationModels
import SwiftData

// MARK: - Cached per-ingredient skin AI summary

@Model
class SkinIngredientModel {
    var name: String
    var explanation: String
    var skinEffect: String
    var suitability: String

    // Rich fields — populated by updated AI analysis.
    var safetyRating: String     = "Generally Safe"  // "Generally Safe" | "Monitor" | "Use Caution" | "Avoid"
    var origin: String           = "Natural"          // "Natural" | "Semi-Synthetic" | "Synthetic"
    var penetrationDepth: String = "Surface"          // "Surface" | "Epidermal" | "Dermal"
    var keyFacts: [String]       = []                 // exactly 3 short scannable facts

    init(name: String, explanation: String, skinEffect: String, suitability: String,
         safetyRating: String = "Generally Safe", origin: String = "Natural",
         penetrationDepth: String = "Surface", keyFacts: [String] = []) {
        self.name             = name
        self.explanation      = explanation
        self.skinEffect       = skinEffect
        self.suitability      = suitability
        self.safetyRating     = safetyRating
        self.origin           = origin
        self.penetrationDepth = penetrationDepth
        self.keyFacts         = keyFacts
    }
}

@Generable
struct SkinIngredientAnalysis {
    @Guide(description: "What this ingredient is and its role in skincare formulations (1-2 sentences).")
    var explanation: String

    @Guide(description: "How skin typically responds to this ingredient — its common effects (1-2 sentences).")
    var skinEffect: String

    @Guide(description: "Whether this ingredient is suitable for the user's specific skin type and conditions (1 sentence, personalized).")
    var suitability: String

    @Guide(description: """
        Skin safety rating. Return EXACTLY one of: \
        'Generally Safe' — well-tolerated by most skin types; \
        'Monitor' — fine for most but watch for sensitivity reactions; \
        'Use Caution' — common irritant or allergen for many people; \
        'Avoid' — widely associated with skin damage or severe reactions.
        """)
    var safetyRating: String

    @Guide(description: """
        Ingredient origin. Return EXACTLY one of: \
        'Natural' — plant, animal, or mineral derived with minimal processing; \
        'Semi-Synthetic' — natural source chemically modified; \
        'Synthetic' — manufactured through chemical synthesis.
        """)
    var origin: String

    @Guide(description: """
        How deeply this ingredient penetrates the skin barrier. Return EXACTLY one of: \
        'Surface' — stays on top of skin, forms a film or barrier (e.g. dimethicone, petrolatum); \
        'Epidermal' — absorbs into outer skin layers (e.g. glycerin, niacinamide, most humectants); \
        'Dermal' — penetrates deeper into dermis (e.g. retinol, hyaluronic acid with small molecular weight, peptides).
        """)
    var penetrationDepth: String

    @Guide(description: """
        Exactly 3 short, scannable skincare facts about this ingredient. \
        Each fact must be 6–12 words. \
        Focus on: skin benefits, compatibility tips, or things to know. \
        Example facts: 'Strengthens skin barrier by attracting water molecules', \
        'Commonly found in moisturisers and serums', 'May increase sun sensitivity — use SPF'.
        """)
    var keyFacts: [String]
}
