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

    init(name: String, explanation: String, digestion: String, digestiveFeel: String) {
        self.name = name
        self.explanation = explanation
        self.digestion = digestion
        self.digestiveFeel = digestiveFeel
    }
}

@Generable
struct IngredientSummary {
    @Guide(description: "Explain this ingredient in a few sentences.")
    let explanation: String

    @Guide(description: "Explain how the body processes this ingredient in a few sentences.")
    let digestion: String

    @Guide(description: "Describe the typical physical experience after consuming or applying this ingredient.")
    let digestiveFeel: String
}
