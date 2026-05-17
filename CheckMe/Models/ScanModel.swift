import Foundation
import SwiftData
import FoundationModels

// MARK: - Scanned Item

@Model
class ScanModel: Identifiable {
    var itemName: String
    var ingredients: [String]

    // Cached scalar count of the ingredients array.
    // SwiftData stores [String] as a binary-faulted attribute, meaning it is lazily
    // loaded and its backing store is immediately cleared on deletion.
    // Any view that reads `ingredients.count` while SwiftUI is still animating a
    // deleted row out of a LazyVStack will crash with "detached from context".
    // Storing the count separately as an Int avoids the fault entirely — scalars
    // are always in-memory and safe to read at any point, including during deletion.
    var ingredientCount: Int = 0

    var dateSaved: Date = Date.now
    var category: String = HealthCategory.food.rawValue

    @Relationship(deleteRule: .cascade)
    var summary: GeneralSummaryModel?

    @Relationship(deleteRule: .cascade)
    var gutPrediction: SavedGutPrediction?

    init(itemName: String, ingredients: [String], category: HealthCategory = .food) {
        self.itemName = itemName
        self.ingredients = ingredients
        self.ingredientCount = ingredients.count  // keep in sync at creation time
        self.category = category.rawValue
    }

    var healthCategory: HealthCategory {
        HealthCategory(rawValue: category) ?? .food
    }
}

// MARK: - Persisted AI Summary

@Model
class GeneralSummaryModel {
    var overview: String
    var digestionProcess: String
    var complexity: String

    init(overview: String, digestionProcess: String, complexity: String) {
        self.overview = overview
        self.digestionProcess = digestionProcess
        self.complexity = complexity
    }
}

// MARK: - Persisted Prediction

@Model
class SavedGutPrediction {
    var prediction: String
    var triggers: [String]   // red — clearly problematic for this user
    var cautions: [String] = []   // yellow — mild concerns worth watching; defaults to [] for backwards compatibility
    var tip: String
    var timestamp: Date

    init(from gutPrediction: GutPrediction) {
        self.prediction = gutPrediction.prediction
        self.triggers = gutPrediction.triggers
        self.cautions = gutPrediction.cautions
        self.tip = gutPrediction.tip
        self.timestamp = Date.now
    }
}

extension SavedGutPrediction {
    func toGutPrediction() -> GutPrediction {
        GutPrediction(prediction: prediction, triggers: triggers, cautions: cautions, tip: tip)
    }
}

// MARK: - Foundation Models Generable Types

// AI-parsed product info from raw OCR text — separates product identity from ingredients
@Generable
struct ProductInfo {
    @Guide(description: """
        The product name and brand, extracted ONLY from text that explicitly identifies the product on the label. \
        Example of a good result: 'Oreo Double Stuf Chocolate Sandwich Cookies by Nabisco'. \
        STRICT RULES: \
        (1) If no product name or brand is visible in the label text, return exactly the string 'Unknown Product'. \
        (2) Never guess, infer, or fabricate a name from ingredients, context, or prior knowledge. \
        (3) Never use an ingredient name as the product name. \
        (4) If unsure, return 'Unknown Product'.
        """)
    var productName: String

    @Guide(description: """
        A flat list where EACH ELEMENT IS EXACTLY ONE INGREDIENT. \
        CRITICAL RULES for sub-ingredients in parentheses: \
        ✓ CORRECT: 'Enriched Flour (Wheat, Niacin, Iron)' is ONE entry \
        ✗ WRONG: Returning 'Enriched Flour' AND 'Wheat' AND 'Niacin' AND 'Iron' separately \
        ✓ CORRECT: 'Natural Flavour (Paprika Extract, Garlic Powder)' stays together \
        ✗ WRONG: Splitting any ingredient that has a parenthetical sub-ingredient list. \
        Split ONLY at top-level commas (outside parentheses). Keep everything in parentheses attached. \
        Never return the entire ingredient list as a single string. \
        Remove percentages, weights, asterisks, footnote markers, and OCR noise. \
        Return an empty array only if no ingredient list is present in the text.
        """)
    var cleanedIngredients: [String]
}

@Generable
struct GeneralSummary {
    @Guide(description: "Provide a short, neutral overview (1–2 sentences) describing what it is generally like to consume or use a product made from the given ingredients.")
    var overview: String

    @Guide(description: "Describe, in general terms, how the ingredients are typically processed by the body.")
    var digestionProcess: String

    @Guide(description: "Describe the overall complexity of the ingredient list in terms of variety and formulation, using neutral language.")
    var complexity: String
}

@Generable
struct GutPrediction {
    @Guide(description: "Rate digestive comfort level using EXACTLY one of these three phrases: 'Gut Friendly' (minimal triggers), 'Moderate Risk' (1–2 mild triggers), or 'High Risk' (3+ serious triggers). Include this exact phrase followed by a brief reason in one sentence.")
    var prediction: String

    @Guide(description: "List ingredients that are CLEARLY problematic for this specific user based on their allergens, digestive conditions, or dietary restrictions — i.e. they should avoid or be very cautious about. If none, return an empty array. Max 5 items.")
    var triggers: [String]

    @Guide(description: "List ingredients that are mild concerns for this user — not dangerous but worth noting (e.g. high sugar for diabetic-friendly diet, legumes for IBS). Different from triggers. If none, return an empty array. Max 5 items.")
    var cautions: [String]

    @Guide(description: "One actionable tip for consuming this product safely. Keep it brief and practical.")
    var tip: String
}
