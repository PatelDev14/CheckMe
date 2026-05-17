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

    init(name: String, explanation: String, skinEffect: String, suitability: String) {
        self.name = name
        self.explanation = explanation
        self.skinEffect = skinEffect
        self.suitability = suitability
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
}
