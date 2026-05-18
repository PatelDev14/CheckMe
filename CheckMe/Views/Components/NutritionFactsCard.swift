import SwiftUI

// Collapsible card showing animated progress rings for each macronutrient.
// Rings animate from 0 → % daily value when the card first expands.
// Each ring is independently coloured by nutrient type; the arc fills
// proportional to the FDA daily reference value.

struct NutritionFactsCard: View {
    let facts: SavedNutritionFacts
    var servingsMultiplier: Double = 1.0
    var startsExpanded: Bool = false

    @Environment(ThemeManager.self) private var themeManager
    @State private var isExpanded = false
    @State private var selectedNutrient: NutrientKnowledge?

    init(facts: SavedNutritionFacts, servingsMultiplier: Double = 1.0, startsExpanded: Bool = false) {
        self.facts = facts
        self.servingsMultiplier = servingsMultiplier
        self.startsExpanded = startsExpanded
        _isExpanded = State(initialValue: startsExpanded)
    }

    private let accentColor = Color(red: 0.55, green: 0.45, blue: 0.95)

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            if isExpanded { expandedContent }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(isExpanded ? 0.4 : 0.18), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isExpanded)
        .sheet(item: $selectedNutrient) { knowledge in
            NutrientInfoSheet(knowledge: knowledge)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.pie.fill")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Nutrition Facts")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Per \(facts.servingSize)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Text("\(Int(facts.calories * servingsMultiplier)) cal")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        Divider().overlay(accentColor.opacity(0.2))

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 18
        ) {
            NutrientRing(label: "Calories", value: facts.calories      * servingsMultiplier, unit: "kcal", daily: NutritionDailyValues.calories,      color: Color(red: 0.55, green: 0.45, blue: 0.95), index: 0) { selectedNutrient = NutrientKnowledge.all["Calories"] }
            NutrientRing(label: "Fat",      value: facts.totalFatG     * servingsMultiplier, unit: "g",    daily: NutritionDailyValues.totalFatG,     color: Color(red: 0.95, green: 0.55, blue: 0.10), index: 1) { selectedNutrient = NutrientKnowledge.all["Fat"] }
            NutrientRing(label: "Carbs",    value: facts.totalCarbsG   * servingsMultiplier, unit: "g",    daily: NutritionDailyValues.totalCarbsG,   color: Color(red: 0.25, green: 0.55, blue: 0.95), index: 2) { selectedNutrient = NutrientKnowledge.all["Carbs"] }
            NutrientRing(label: "Protein",  value: facts.proteinG      * servingsMultiplier, unit: "g",    daily: NutritionDailyValues.proteinG,      color: Color(red: 0.20, green: 0.80, blue: 0.45), index: 3) { selectedNutrient = NutrientKnowledge.all["Protein"] }
            NutrientRing(label: "Sugar",    value: facts.sugarG        * servingsMultiplier, unit: "g",    daily: NutritionDailyValues.sugarG,        color: Color(red: 0.95, green: 0.25, blue: 0.25), index: 4) { selectedNutrient = NutrientKnowledge.all["Sugar"] }
            NutrientRing(label: "Sodium",   value: facts.sodiumMg      * servingsMultiplier, unit: "mg",   daily: NutritionDailyValues.sodiumMg,      color: Color(red: 0.95, green: 0.80, blue: 0.15), index: 5) { selectedNutrient = NutrientKnowledge.all["Sodium"] }
            NutrientRing(label: "Fiber",    value: facts.fiberG        * servingsMultiplier, unit: "g",    daily: NutritionDailyValues.fiberG,        color: Color(red: 0.30, green: 0.80, blue: 0.55), index: 6) { selectedNutrient = NutrientKnowledge.all["Fiber"] }
            NutrientRing(label: "Sat. Fat", value: facts.saturatedFatG * servingsMultiplier, unit: "g",    daily: NutritionDailyValues.saturatedFatG, color: Color(red: 0.95, green: 0.45, blue: 0.15), index: 7) { selectedNutrient = NutrientKnowledge.all["Sat. Fat"] }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .transition(.opacity.combined(with: .move(edge: .top)))

        HStack {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
            Text("Tap any nutrient to learn more  ·  % Daily Values based on a 2,000 calorie diet")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.28))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

// MARK: - Individual Nutrient Ring

private struct NutrientRing: View {
    let label: String
    let value: Double
    let unit: String
    let daily: Double
    let color: Color
    let index: Int
    let onTap: () -> Void

    @State private var progress: Double = 0

    private var target: Double { daily > 0 ? min(value / daily, 1.0) : 0 }
    private var percentLabel: String { "\(Int(target * 100))%*" }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    // Track
                    Circle()
                        .stroke(.white.opacity(0.07), lineWidth: 7)
                        .frame(width: 60, height: 60)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    // Center label
                    VStack(spacing: 1) {
                        Text(formattedValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(unit)
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Text(percentLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(color.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            // Stagger each ring by 70 ms; spring handles the motion
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.07) {
                withAnimation(.spring(response: 0.75, dampingFraction: 0.65)) {
                    progress = target
                }
            }
        }
    }

    private var formattedValue: String {
        if value >= 1000 { return String(format: "%.0f", value) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }
}
