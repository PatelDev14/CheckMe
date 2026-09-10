import Foundation
import SwiftData

// MARK: - Logged Entry (Nutrient Diary)

/// Represents a single "I consumed/used this" log event.
///
/// Two tiers:
/// - Simple log (Food / Personal Care tabs): `hasNutritionData == false`, only
///   `itemName`/`category`/`timestamp` are meaningful — used for ingredient-exposure
///   tracking and history, no macro math involved.
/// - Nutrition log (Nutrition tab): `hasNutritionData == true` — `consumed*` fields are
///   a SNAPSHOT of the macro/micronutrient values at the chosen portion size, computed as
///   `nutritionFacts.value * portionMultiplier` at the moment of logging. Snapshotting
///   avoids recomputation issues if the underlying scan is later edited or deleted.
@Model
class LoggedEntry: Identifiable {
    /// When this entry was logged (user-editable — defaults to now).
    var timestamp: Date = Date.now

    /// Start-of-day for `timestamp`, stored separately for fast day-based grouping/queries.
    var date: Date = Date.now

    /// Snapshot of the product name at the time of logging, so the entry remains
    /// meaningful even if the source scan is renamed or deleted.
    var itemName: String = ""

    /// Snapshot of `HealthCategory.rawValue` (food / nutrition / personalCare).
    var category: String = HealthCategory.food.rawValue

    /// Whether this entry carries a macro/micronutrient snapshot.
    var hasNutritionData: Bool = false

    /// Portion multiplier chosen at logging time (e.g. 0.5, 1.0, 1.5, 2.0).
    var portionMultiplier: Double = 1.0

    /// Display label for the portion (e.g. "1×", "½×") and the original serving size text.
    var portionLabel: String = "1×"
    var servingSize: String = ""

    /// Meal type chosen at logging time for nutrition entries (e.g. "Breakfast", "Lunch",
    /// "Dinner", "Snack"). Empty for simple food/personal-care logs.
    var mealType: String = ""

    /// Snapshot of allergens from the source nutrition facts, if any.
    var allergens: [String] = []

    /// Snapshot of the gut-prediction rating at the time of logging (e.g. "Gut Friendly",
    /// "Moderate Risk", "High Risk") — populated for Food-tab logs.
    var gutRatingLabel: String = ""

    /// Snapshot of trigger / caution ingredients flagged for this user at the time of logging.
    var triggers: [String] = []
    var cautions: [String] = []

    // MARK: Consumed nutrient snapshot (already multiplied by portionMultiplier)

    var consumedCalories: Double = 0
    var consumedFatG: Double = 0
    var consumedSaturatedFatG: Double = 0
    var consumedCarbsG: Double = 0
    var consumedFiberG: Double = 0
    var consumedSugarG: Double = 0
    var consumedProteinG: Double = 0
    var consumedSodiumMg: Double = 0
    var consumedPotassiumMg: Double = 0
    var consumedCalciumMg: Double = 0
    var consumedIronMg: Double = 0
    var consumedVitaminDMcg: Double = 0
    var consumedVitaminAMcg: Double = 0
    var consumedVitaminCMg: Double = 0

    /// Link back to the source scan, if it still exists. `.nullify` so deleting a scan
    /// keeps the diary entry (with its snapshot data) intact.
    @Relationship(deleteRule: .nullify, inverse: \ScanModel.loggedEntries)
    var scan: ScanModel?

    init(
        scan: ScanModel,
        timestamp: Date = .now,
        portionMultiplier: Double = 1.0,
        portionLabel: String = "1×",
        mealType: String = "",
        nutrition: SavedNutritionFacts? = nil,
        gutPrediction: SavedGutPrediction? = nil
    ) {
        self.timestamp = timestamp
        self.date = Calendar.current.startOfDay(for: timestamp)
        self.itemName = scan.itemName
        self.category = scan.category
        self.scan = scan
        self.portionMultiplier = portionMultiplier
        self.portionLabel = portionLabel

        if let nutrition {
            self.hasNutritionData = true
            self.servingSize = nutrition.servingSize
            self.mealType = mealType
            self.allergens = nutrition.allergens
            self.consumedCalories      = nutrition.calories      * portionMultiplier
            self.consumedFatG          = nutrition.totalFatG     * portionMultiplier
            self.consumedSaturatedFatG = nutrition.saturatedFatG * portionMultiplier
            self.consumedCarbsG        = nutrition.totalCarbsG   * portionMultiplier
            self.consumedFiberG        = nutrition.fiberG        * portionMultiplier
            self.consumedSugarG        = nutrition.sugarG        * portionMultiplier
            self.consumedProteinG      = nutrition.proteinG      * portionMultiplier
            self.consumedSodiumMg      = nutrition.sodiumMg      * portionMultiplier
            self.consumedPotassiumMg   = nutrition.potassiumMg   * portionMultiplier
            self.consumedCalciumMg     = nutrition.calciumMg     * portionMultiplier
            self.consumedIronMg        = nutrition.ironMg        * portionMultiplier
            self.consumedVitaminDMcg   = nutrition.vitaminDMcg   * portionMultiplier
            self.consumedVitaminAMcg   = nutrition.vitaminAMcg   * portionMultiplier
            self.consumedVitaminCMg    = nutrition.vitaminCMg    * portionMultiplier
        } else {
            self.hasNutritionData = false
        }

        if let gutPrediction {
            self.gutRatingLabel = GutRating(from: gutPrediction.prediction).label
            self.triggers = gutPrediction.triggers
            self.cautions = gutPrediction.cautions
        }
    }

    var healthCategory: HealthCategory {
        HealthCategory(rawValue: category) ?? .food
    }
}
