import SwiftUI

struct MicronutrientsView: View {
    let nutrition: SavedNutritionFacts
    let servingsMultiplier: Double

    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedNutrient: NutrientKnowledge?

    private let accentColor = Color(red: 0.55, green: 0.45, blue: 0.95)

    var micronutrients: [MicronutrientInfo] {
        [
            MicronutrientInfo(label: "Vitamin A", value: nutrition.vitaminAMcg * servingsMultiplier, dailyValue: NutritionDailyValues.vitaminAMcg, unit: "mcg"),
            MicronutrientInfo(label: "Vitamin C", value: nutrition.vitaminCMg * servingsMultiplier, dailyValue: NutritionDailyValues.vitaminCMg, unit: "mg"),
            MicronutrientInfo(label: "Vitamin D", value: nutrition.vitaminDMcg * servingsMultiplier, dailyValue: NutritionDailyValues.vitaminDMcg, unit: "mcg"),
            MicronutrientInfo(label: "Calcium", value: nutrition.calciumMg * servingsMultiplier, dailyValue: NutritionDailyValues.calciumMg, unit: "mg"),
            MicronutrientInfo(label: "Iron", value: nutrition.ironMg * servingsMultiplier, dailyValue: NutritionDailyValues.ironMg, unit: "mg"),
            MicronutrientInfo(label: "Potassium", value: nutrition.potassiumMg * servingsMultiplier, dailyValue: NutritionDailyValues.potassiumMg, unit: "mg")
        ].filter { $0.value > 0 }
    }

    var body: some View {
        if !micronutrients.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "capsule.fill")
                        .foregroundStyle(accentColor)
                    Text("Micronutrients")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    ForEach(micronutrients, id: \.label) { nutrient in
                        micronutrientRow(nutrient)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Tap any nutrient to learn more")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.28))
                    Spacer()
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
            .sheet(item: $selectedNutrient) { knowledge in
                NutrientInfoSheet(knowledge: knowledge)
            }
        }
    }

    private func micronutrientRow(_ nutrient: MicronutrientInfo) -> some View {
        Button {
            selectedNutrient = NutrientKnowledge.all[nutrient.label]
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nutrient.label)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("\(String(format: "%.1f", nutrient.value)) \(nutrient.unit)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(nutrient.percentDailyValue)%")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                    Text("Daily Value")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(accentColor.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
