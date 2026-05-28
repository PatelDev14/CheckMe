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
    var capturedImagePath: String? = nil

    @Relationship(deleteRule: .cascade)
    var summary: GeneralSummaryModel?

    @Relationship(deleteRule: .cascade)
    var gutPrediction: SavedGutPrediction?

    @Relationship(deleteRule: .cascade)
    var skinPrediction: SavedSkinPrediction?

    @Relationship(deleteRule: .cascade)
    var skinCategories: SavedSkinCategories?

    @Relationship(deleteRule: .cascade)
    var nutritionFacts: SavedNutritionFacts?

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

// MARK: - Skin Prediction (Persisted)

@Model
class SavedSkinPrediction {
    var rating: String          // "Skin Friendly" | "Moderate Concern" | "High Concern"
    var summary: String
    var irritants: [String]     // red — avoid for this user's skin
    var cautions: [String]      // yellow — mild concerns
    var tip: String
    var timestamp: Date

    init(from prediction: SkinPrediction) {
        self.rating = prediction.rating
        self.summary = prediction.summary
        self.irritants = prediction.irritants
        self.cautions = prediction.cautions
        self.tip = prediction.tip
        self.timestamp = Date.now
    }
}

// MARK: - Skin Foundation Models Generable Types

@Generable
struct SkinProductInfo {
    @Guide(description: """
        The product name and brand, extracted ONLY from text that explicitly identifies the product on the label. \
        Example: 'CeraVe Moisturising Cream'. \
        STRICT RULES: \
        (1) If no product name or brand is visible, return exactly the string 'Unknown Product'. \
        (2) Never guess, infer, or fabricate a name from ingredients. \
        (3) Never use an ingredient name as the product name. \
        (4) If unsure, return 'Unknown Product'.
        """)
    var productName: String

    @Guide(description: """
        A flat list where EACH ELEMENT IS EXACTLY ONE INGREDIENT. \
        CRITICAL RULES for sub-ingredients in parentheses: \
        ✓ CORRECT: 'Cetearyl Alcohol (and) Ceteareth-20' is ONE entry \
        ✗ WRONG: Splitting any ingredient that has a parenthetical sub-ingredient list. \
        Split ONLY at top-level commas (outside parentheses). Keep everything in parentheses attached. \
        Remove percentages, symbols, asterisks, and OCR noise. \
        Return an empty array only if no ingredient list is present in the text.
        """)
    var cleanedIngredients: [String]
}

@Generable
struct SkinPrediction {
    @Guide(description: "Use EXACTLY one of: 'Skin Friendly', 'Moderate Concern', or 'High Concern'. Follow with one sentence explaining why.")
    var rating: String

    @Guide(description: "1-2 sentence overview of this product's skin compatibility for this user.")
    var summary: String

    @Guide(description: "Ingredients the user should AVOID based on their skin profile (irritants, allergens, known triggers for their conditions). Max 5. Empty array if none.")
    var irritants: [String]

    @Guide(description: "Mild skin concerns — comedogenic ingredients, synthetic fragrance, alcohol, common sensitizers. Not dangerous but worth noting. Max 5. Empty array if none.")
    var cautions: [String]

    @Guide(description: "One practical skincare tip for using products with this ingredient profile.")
    var tip: String
}

// MARK: - Skin Ingredient Categories

/// Classifies every ingredient into functional skincare categories.
/// Stored as a JSON-encoded [String:[String]] in a single scalar field to avoid
/// SwiftData complexity — decoded on read via SavedSkinCategories.decoded().
@Model
class SavedSkinCategories {
    /// JSON-encoded dictionary: category name → [ingredient name]
    var categoriesJSON: String = "{}"
    var timestamp: Date = Date.now

    init(from result: SkinIngredientCategories) {
        let dict: [String: [String]] = [
            "Actives":      result.actives,
            "Humectants":   result.humectants,
            "Emollients":   result.emollients,
            "Occlusives":   result.occlusives,
            "Preservatives":result.preservatives,
            "Fragrances":   result.fragrances,
            "Surfactants":  result.surfactants,
            "Other":        result.other,
        ]
        if let data = try? JSONEncoder().encode(dict),
           let str  = String(data: data, encoding: .utf8) {
            categoriesJSON = str
        }
    }

    /// Decode back to [category: [ingredient]] — empty dict on failure.
    func decoded() -> [(category: String, ingredients: [String])] {
        guard let data = categoriesJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [] }

        // Fixed display order
        let order = ["Actives", "Humectants", "Emollients", "Occlusives",
                     "Preservatives", "Fragrances", "Surfactants", "Other"]
        return order.compactMap { key in
            guard let items = dict[key], !items.isEmpty else { return nil }
            return (category: key, ingredients: items)
        }
    }
}

@Generable
struct SkinIngredientCategories {
    @Guide(description: """
        Ingredients that are bioactive — they change skin chemistry or target specific concerns. \
        Examples: retinol, niacinamide, vitamin C (ascorbic acid), AHA (glycolic acid, lactic acid), \
        BHA (salicylic acid), azelaic acid, bakuchiol, peptides, growth factors, collagen, hyaluronic acid (when used as active). \
        Return empty array if none.
        """)
    var actives: [String]

    @Guide(description: """
        Ingredients that draw moisture into the skin. \
        Examples: glycerin, hyaluronic acid, sodium PCA, aloe vera, panthenol, honey, urea, \
        propylene glycol, sorbitol, amino acids. Return empty array if none.
        """)
    var humectants: [String]

    @Guide(description: """
        Ingredients that soften and smooth the skin by filling gaps in the lipid barrier. \
        Examples: squalane, jojoba oil, rosehip oil, cetyl alcohol, cetearyl alcohol, \
        isopropyl myristate, caprylic/capric triglyceride, shea butter, fatty acids. \
        Return empty array if none.
        """)
    var emollients: [String]

    @Guide(description: """
        Ingredients that form a barrier on the skin surface to prevent water loss. \
        Examples: petrolatum, dimethicone, cyclomethicone, beeswax, lanolin, mineral oil, \
        zinc oxide, titanium dioxide. Return empty array if none.
        """)
    var occlusives: [String]

    @Guide(description: """
        Ingredients that prevent microbial growth and extend product shelf life. \
        Examples: phenoxyethanol, parabens (methylparaben, propylparaben), benzyl alcohol, \
        ethylhexylglycerin, sodium benzoate, potassium sorbate, DMDM hydantoin, \
        formaldehyde releasers, caprylyl glycol. Return empty array if none.
        """)
    var preservatives: [String]

    @Guide(description: """
        Fragrance compounds — both synthetic and natural. \
        Examples: parfum, fragrance, linalool, limonene, citronellol, geraniol, benzyl benzoate, \
        eugenol, cinnamal, essential oils (lavender oil, rose oil, peppermint oil). \
        Return empty array if none.
        """)
    var fragrances: [String]

    @Guide(description: """
        Ingredients that cleanse by reducing surface tension (mainly in rinse-off products). \
        Examples: sodium lauryl sulfate (SLS), sodium laureth sulfate (SLES), cocamidopropyl betaine, \
        coco-glucoside, decyl glucoside, ammonium lauryl sulfate. Return empty array if none.
        """)
    var surfactants: [String]

    @Guide(description: """
        Any ingredient that does not fit the above categories. \
        Includes: thickeners (carbomer, xanthan gum), pH adjusters (citric acid, sodium hydroxide), \
        chelating agents (EDTA), colorants, sunscreen filters (avobenzone, oxybenzone), \
        emulsifiers, solvents (water, alcohol denat), and anything uncategorised. \
        Return empty array if none.
        """)
    var other: [String]
}
