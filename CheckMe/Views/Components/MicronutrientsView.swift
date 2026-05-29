import SwiftUI

struct MicronutrientsView: View {
    let nutrition: SavedNutritionFacts
    let servingsMultiplier: Double

    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedNutrient: NutrientKnowledge?

    // All nutrients in label order (US FDA 2020 format).
    // Always show all — zero means "not listed on label".
    var micronutrients: [MicronutrientInfo] {
        [
            MicronutrientInfo(label: "Vitamin D", value: nutrition.vitaminDMcg  * servingsMultiplier, dailyValue: NutritionDailyValues.vitaminDMcg,  unit: "mcg"),
            MicronutrientInfo(label: "Calcium",   value: nutrition.calciumMg    * servingsMultiplier, dailyValue: NutritionDailyValues.calciumMg,    unit: "mg"),
            MicronutrientInfo(label: "Iron",      value: nutrition.ironMg       * servingsMultiplier, dailyValue: NutritionDailyValues.ironMg,       unit: "mg"),
            MicronutrientInfo(label: "Potassium", value: nutrition.potassiumMg  * servingsMultiplier, dailyValue: NutritionDailyValues.potassiumMg,  unit: "mg"),
            MicronutrientInfo(label: "Vitamin A", value: nutrition.vitaminAMcg  * servingsMultiplier, dailyValue: NutritionDailyValues.vitaminAMcg,  unit: "mcg"),
            MicronutrientInfo(label: "Vitamin C", value: nutrition.vitaminCMg   * servingsMultiplier, dailyValue: NutritionDailyValues.vitaminCMg,   unit: "mg"),
        ]
        // No filter — show all so users see which are/aren't on the label.
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "capsule.fill")
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                Text("Vitamins & Minerals")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text("% Daily Value")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }

            // Divider
            Rectangle()
                .fill(themeManager.selectedTheme.colors.accent.opacity(0.15))
                .frame(height: 0.5)

            // Rows
            VStack(spacing: 0) {
                ForEach(Array(micronutrients.enumerated()), id: \.element.label) { index, nutrient in
                    micronutrientRow(nutrient, isLast: index == micronutrients.count - 1)
                }
            }

            // Footnote
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Tap any nutrient to learn more  ·  — means not listed on this label")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.28))
                Spacer()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeManager.selectedTheme.colors.accent.opacity(0.2), lineWidth: 1))
        .sheet(item: $selectedNutrient) { knowledge in
            NutrientInfoSheet(knowledge: knowledge)
        }
    }

    @ViewBuilder
    private func micronutrientRow(_ nutrient: MicronutrientInfo, isLast: Bool) -> some View {
        let isListed = nutrient.value > 0
        let pct = nutrient.percentDailyValue

        Button {
            selectedNutrient = NutrientKnowledge.all[nutrient.label]
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Name + value
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nutrient.label)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(isListed ? .white : .white.opacity(0.40))

                        if isListed {
                            Text(formatValue(nutrient.value, unit: nutrient.unit))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.50))
                        } else {
                            Text("Not listed on label")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.28))
                        }
                    }

                    Spacer()

                    // Progress bar + percentage
                    if isListed {
                        HStack(spacing: 10) {
                            // Mini progress bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(themeManager.selectedTheme.colors.accent.opacity(0.12))
                                    .frame(width: 64, height: 5)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(barColor(pct: pct))
                                    .frame(width: max(3, 64 * CGFloat(min(pct, 100)) / 100), height: 5)
                            }

                            Text("\(pct)%")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(barColor(pct: pct))
                                .frame(minWidth: 36, alignment: .trailing)
                        }
                    } else {
                        Text("—")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.22))
                            .frame(minWidth: 36, alignment: .trailing)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(isListed ? 0.22 : 0.10))
                }
                .padding(.vertical, 11)

                if !isLast {
                    Divider()
                        .background(Color.white.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double, unit: String) -> String {
        let num = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        return "\(num) \(unit)"
    }

    /// Colours the progress bar green → amber → red by % daily value.
    private func barColor(pct: Int) -> Color {
        if pct >= 20 { return Color(red: 0.95, green: 0.45, blue: 0.15) }   // high — amber
        if pct >= 10 { return themeManager.selectedTheme.colors.accent }    // medium — accent
        return Color(red: 0.30, green: 0.80, blue: 0.55)                     // low — green
    }
}
