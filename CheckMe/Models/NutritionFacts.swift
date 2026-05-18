import SwiftUI
import SwiftData
import FoundationModels

// MARK: - AI Generable Types

@Generable
struct NutritionFactsExtraction {
    @Guide(description: "Serving size exactly as printed on the label (e.g. '1 cup (240 ml)', '100 g', '2 tbsp'). Empty string if not found.")
    var servingSize: String

    @Guide(description: "Calories per serving as a plain number string (e.g. '250'). Return '0' if not found.")
    var calories: String

    @Guide(description: "Total fat in grams per serving, number only, no units (e.g. '12'). Return '0' if not found.")
    var totalFatG: String

    @Guide(description: "Saturated fat in grams per serving, number only. Return '0' if not found.")
    var saturatedFatG: String

    @Guide(description: "Total carbohydrates in grams per serving, number only. Return '0' if not found.")
    var totalCarbsG: String

    @Guide(description: "Dietary fiber in grams per serving, number only. Return '0' if not found.")
    var fiberG: String

    @Guide(description: "Total sugars in grams per serving, number only. Return '0' if not found.")
    var sugarG: String

    @Guide(description: "Protein in grams per serving, number only. Return '0' if not found.")
    var proteinG: String

    @Guide(description: "Sodium in milligrams per serving, number only (e.g. '460'). If the label uses 'mg', return as-is. Only multiply by 1000 when the label explicitly says 'g' or 'grams'. Return '0' if not found.")
    var sodiumMg: String

    @Guide(description: "Potassium in milligrams per serving (if listed on label), number only. Return '0' if not found.")
    var potassiumMg: String

    @Guide(description: "Vitamin D in micrograms per serving (if listed), number only. Return '0' if not found.")
    var vitaminDMcg: String

    @Guide(description: "Calcium in milligrams per serving (if listed), number only. Return '0' if not found.")
    var calciumMg: String

    @Guide(description: "Iron in milligrams per serving (if listed), number only. Return '0' if not found.")
    var ironMg: String

    @Guide(description: "Vitamin A in micrograms RAE per serving (if listed), number only. Return '0' if not found.")
    var vitaminAMcg: String

    @Guide(description: "Vitamin C in milligrams per serving (if listed), number only. Return '0' if not found.")
    var vitaminCMg: String

    @Guide(description: """
        List of allergens from the 'Contains:' or 'Allergens:' statement printed on the label \
        (e.g. ['Wheat', 'Milk', 'Soy']). Return an empty array if no allergen statement is present. \
        Do NOT infer allergens — only return what is explicitly stated.
        """)
    var allergens: [String]
}

@Generable
struct NutritionProductName {
    @Guide(description: """
        The product name and brand visible anywhere on the label, including the nutrition panel header. \
        Example: 'Quaker Oats Old Fashioned Oatmeal'. \
        Return exactly 'Unknown Product' if no product name is visible.
        """)
    var productName: String
}

// AI determines container shape only — composition is computed from actual nutrition data.
@Generable
struct ContainerTypeResult {
    @Guide(description: """
    Container shape that best represents this product physically:
    'bottle' — any liquid beverage (water, soda, juice, sports drink, milk, tea, energy drink, cola)
    'jar'    — thick spreads and pastes (peanut butter, Nutella, jam, yogurt, hummus, cream cheese, salsa)
    'bag'    — flexible snack packaging (chips, popcorn, crackers, nuts, gummy candy, trail mix, granola bar)
    'box'    — rigid dry goods (cereal, oatmeal, pasta, rice, cookies, protein powder) and everything else
    Only return one of these four exact strings.
    """)
    var containerType: String
}

// Plain struct — not AI-generated. Filled by NutritionViewModel.computeCompositionLayers().
struct NutritionLayers {
    var containerType: String
    var layerNames: [String]
    var layerPercents: [String]
}

@Generable
struct NutritionInsight {
    @Guide(description: """
        2–3 sentences analysing this product's macro profile. Cover: \
        (1) how many calories this serving provides relative to a 2,000 cal/day diet, \
        (2) whether sugar or sodium is notably high or low, \
        (3) one practical observation for the buyer (e.g. good protein source, high in saturated fat). \
        Use plain, friendly language — not alarmist.
        """)
    var summary: String
}

// MARK: - SwiftData Model

@Model
class SavedNutritionFacts {
    var servingSize: String
    var calories: Double
    var totalFatG: Double
    var saturatedFatG: Double
    var totalCarbsG: Double
    var fiberG: Double
    var sugarG: Double
    var proteinG: Double
    var sodiumMg: Double
    var potassiumMg: Double = 0
    var vitaminDMcg: Double = 0
    var calciumMg: Double = 0
    var ironMg: Double = 0
    var vitaminAMcg: Double = 0
    var vitaminCMg: Double = 0
    var aiInsight: String
    var containerType: String = "box"
    var fillLayerNames: [String] = []
    var fillLayerPercents: [String] = []
    var allergens: [String] = []
    var timestamp: Date

    init(from extraction: NutritionFactsExtraction, insight: String = "", layers: NutritionLayers? = nil) {
        self.servingSize    = extraction.servingSize.isEmpty ? "1 serving" : extraction.servingSize
        self.calories       = Self.parse(extraction.calories)
        self.totalFatG      = Self.parse(extraction.totalFatG)
        self.saturatedFatG  = Self.parse(extraction.saturatedFatG)
        self.totalCarbsG    = Self.parse(extraction.totalCarbsG)
        self.fiberG         = Self.parse(extraction.fiberG)
        self.sugarG         = Self.parse(extraction.sugarG)
        self.proteinG       = Self.parse(extraction.proteinG)
        self.sodiumMg       = min(Self.parse(extraction.sodiumMg), 3500)
        self.potassiumMg    = Self.parse(extraction.potassiumMg)
        self.vitaminDMcg    = Self.parse(extraction.vitaminDMcg)
        self.calciumMg      = Self.parse(extraction.calciumMg)
        self.ironMg         = Self.parse(extraction.ironMg)
        self.vitaminAMcg    = Self.parse(extraction.vitaminAMcg)
        self.vitaminCMg     = Self.parse(extraction.vitaminCMg)
        self.aiInsight          = insight
        self.containerType      = layers?.containerType ?? "box"
        self.fillLayerNames     = layers?.layerNames ?? []
        self.fillLayerPercents  = layers?.layerPercents ?? []
        self.allergens          = extraction.allergens
        self.timestamp          = Date.now
    }

    /// True if at least one macronutrient was extracted.
    var hasData: Bool {
        calories > 0 || totalFatG > 0 || totalCarbsG > 0 || proteinG > 0
    }

    /// Tolerant number parser — strips non-numeric chars if direct conversion fails.
    private static func parse(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let d = Double(trimmed) { return d }
        let numeric = trimmed.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        return Double(numeric) ?? 0
    }
}

// MARK: - FDA Daily Reference Values (2020–2025)

enum NutritionDailyValues {
    static let calories:      Double = 2000
    static let totalFatG:     Double = 78
    static let saturatedFatG: Double = 20
    static let totalCarbsG:   Double = 275
    static let fiberG:        Double = 28
    static let sugarG:        Double = 50
    static let proteinG:      Double = 50
    static let sodiumMg:      Double = 2300
    static let potassiumMg:   Double = 4700
    static let calciumMg:     Double = 1300
    static let ironMg:        Double = 18
    static let vitaminDMcg:   Double = 20
    static let vitaminAMcg:   Double = 900
    static let vitaminCMg:    Double = 90
}

// Micronutrient display helper
struct MicronutrientInfo {
    let label: String
    let value: Double
    let dailyValue: Double
    let unit: String

    var percentDailyValue: Int {
        Int((value / dailyValue * 100).rounded())
    }
}
