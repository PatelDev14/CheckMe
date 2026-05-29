import SwiftUI
import SwiftData

/// Shows the real results view (IngredientsListView / NutritionResultsView / SkinResultsView)
/// pre-populated with hardcoded sample data so new users can experience the full
/// interactive UI before they scan their first label.
///
/// Uses an in-memory ModelContainer so sample data never touches the user's persistent store.
/// A stub UserProfileStore with a complete profile is injected so nudge banners
/// ("Set your skin profile", "Complete your food profile", etc.) don't appear.
struct ExampleResultSheet: View {
    let category: HealthCategory

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    /// Stub profile store — skin type, food restrictions, etc. are set so all
    /// "complete your profile" nudges are suppressed. Never written to UserDefaults
    /// because `UserProfileStore.init(previewProfile:)` skips the `didSet` save.
    private static let stubProfileStore: UserProfileStore = {
        var profile = UserProfile()
        profile.skinType = "Normal"
        profile.skinConditions = []
        profile.foodRestrictions = []
        profile.foodAllergies = []
        profile.digestiveConditions = []
        return UserProfileStore(previewProfile: profile)
    }()

    @State private var container: ModelContainer?
    @State private var sampleScan: ScanModel?
    @State private var buildFailed = false

    var body: some View {
        Group {
            if buildFailed {
                errorView
            } else if let container, let scan = sampleScan {
                NavigationStack {
                    resultView(scan: scan)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                                    .fontWeight(.semibold)
                            }
                        }
                }
                .modelContainer(container)
                .environment(Self.stubProfileStore)
            } else {
                loadingView
            }
        }
        .task { await buildSampleContainer() }
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(scan: ScanModel) -> some View {
        switch category {
        case .food:
            IngredientsListView(scan: scan)
        case .nutrition:
            NutritionResultsView(scan: scan)
        case .skin:
            SkinResultsView(scan: scan)
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        ZStack {
            AnimatedThemeBackground(theme: themeManager.selectedTheme)
            VStack(spacing: 14) {
                ProgressView().tint(.white)
                Text("Loading example…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var errorView: some View {
        ZStack {
            AnimatedThemeBackground(theme: themeManager.selectedTheme)
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
                Text("Couldn't load example.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                Button("Close") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Build in-memory container

    @MainActor
    private func buildSampleContainer() async {
        let schema = Schema([
            ScanModel.self,
            GeneralSummaryModel.self,
            SavedGutPrediction.self,
            SavedSkinPrediction.self,
            SavedSkinCategories.self,
            SavedNutritionFacts.self,
            IngredientsModel.self,
            SkinIngredientModel.self,
        ])
        guard let newContainer = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ) else {
            buildFailed = true
            return
        }

        let ctx = newContainer.mainContext
        let scan: ScanModel

        switch category {
        case .food:      scan = buildFoodScan(ctx: ctx)
        case .nutrition: scan = buildNutritionScan(ctx: ctx)
        case .skin:      scan = buildSkinScan(ctx: ctx)
        }

        try? ctx.save()
        container = newContainer
        sampleScan = scan
    }

    // MARK: - Sample data builders

    private func buildFoodScan(ctx: ModelContext) -> ScanModel {
        let scan = ScanModel(
            itemName: "Kellogg's Corn Flakes",
            ingredients: [
                "Milled corn", "Sugar", "Salt", "Malt flavouring",
                "Niacinamide (Vitamin B3)", "Iron", "Zinc oxide", "Vitamin B6",
                "Riboflavin (Vitamin B2)", "Thiamine mononitrate (Vitamin B1)",
                "Folic acid", "Vitamin D3", "Vitamin B12",
            ],
            category: .food
        )
        ctx.insert(scan)

        let gut = SavedGutPrediction(from: GutPrediction(
            prediction: "Gut Friendly — whole grain corn base with minimal gut triggers",
            triggers: [],
            cautions: ["Sugar — moderate amount worth monitoring"],
            tip: "Enjoy with low-fat milk or a plant-based alternative. Opt for smaller portions if you are sensitive to refined sugars."
        ))
        ctx.insert(gut)
        scan.gutPrediction = gut

        let summary = GeneralSummaryModel(
            overview: "A classic breakfast cereal made from milled corn, lightly sweetened and fortified with essential vitamins and minerals.",
            digestionProcess: "Corn starch is rapidly broken down and absorbed as glucose. The added B-vitamins and iron are bioavailable and absorbed in the small intestine.",
            complexity: "Moderately simple ingredient list — whole grain corn dominates, with a small number of additives and fortification nutrients."
        )
        ctx.insert(summary)
        scan.summary = summary

        return scan
    }

    private func buildNutritionScan(ctx: ModelContext) -> ScanModel {
        let scan = ScanModel(
            itemName: "Blueberry Muffin",
            ingredients: [],
            category: .nutrition
        )
        ctx.insert(scan)

        let extraction = NutritionFactsExtraction(
            servingSize: "Per muffin (100 g)",
            calories: "360",
            totalFatG: "16", saturatedFatG: "3.5",
            totalCarbsG: "49", fiberG: "1", sugarG: "27",
            proteinG: "6", sodiumMg: "340",
            potassiumMg: "120",
            vitaminDMcg: "0", calciumMg: "50",
            ironMg: "2",
            vitaminAMcg: "0", vitaminCMg: "0",
            allergens: ["Wheat", "Milk", "Eggs"]
        )
        let facts = SavedNutritionFacts(
            from: extraction,
            insight: "This muffin delivers 18% of a typical 2,000 kcal daily budget in a single serving. Sugar is notably high at 27 g — about 54% of the recommended daily limit. It provides a moderate 6 g of protein, making it a reasonable occasional treat rather than a daily staple."
        )
        ctx.insert(facts)
        scan.nutritionFacts = facts

        return scan
    }

    private func buildSkinScan(ctx: ModelContext) -> ScanModel {
        let scan = ScanModel(
            itemName: "NIVEA MEN Energy Body Wash",
            ingredients: [
                "Water", "Sodium Laureth Sulfate", "Cocamidopropyl Betaine",
                "PEG-7 Glyceryl Cocoate", "Parfum/Fragrance", "Glycerin",
                "Menthol", "Polyquaternium-7", "Alcohol Denat.",
                "Sodium Chloride", "Citric Acid", "Sodium Benzoate",
            ],
            category: .skin
        )
        ctx.insert(scan)

        let skinPred = SavedSkinPrediction(from: SkinPrediction(
            rating: "Moderate Concern — contains fragrance and alcohol that may irritate sensitive skin",
            summary: "This body wash uses surfactants for effective cleansing with a refreshing menthol note. Alcohol Denat. and synthetic fragrance are mild concerns for sensitive or dry skin types.",
            irritants: ["Alcohol Denat."],
            cautions: ["Parfum/Fragrance", "Sodium Laureth Sulfate"],
            tip: "Rinse thoroughly and follow up with a moisturiser. Patch test on a small area first if you have reactive or sensitive skin."
        ))
        ctx.insert(skinPred)
        scan.skinPrediction = skinPred

        let cats = SavedSkinCategories(from: SkinIngredientCategories(
            actives: ["Menthol"],
            humectants: ["Glycerin"],
            emollients: ["PEG-7 Glyceryl Cocoate"],
            occlusives: [],
            preservatives: ["Sodium Benzoate"],
            fragrances: ["Parfum/Fragrance"],
            surfactants: ["Sodium Laureth Sulfate", "Cocamidopropyl Betaine"],
            other: ["Water", "Polyquaternium-7", "Alcohol Denat.", "Sodium Chloride", "Citric Acid"]
        ))
        ctx.insert(cats)
        scan.skinCategories = cats

        return scan
    }
}
