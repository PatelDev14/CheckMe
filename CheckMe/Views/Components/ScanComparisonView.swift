import SwiftUI

/// Side-by-side comparison of two scans from the same category.
/// Triggered from select-mode bottom bar when exactly 2 scans are chosen.
struct ScanComparisonView: View {
    let scanA: ScanModel
    let scanB: ScanModel

    @Environment(ThemeManager.self) private var themeManager

    // MARK: - Ingredient overlap (case-insensitive)

    private var sharedIngredients: [String] {
        let setB = Set(scanB.ingredients.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        return scanA.ingredients.filter {
            setB.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private var uniqueToA: [String] {
        let setB = Set(scanB.ingredients.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        return scanA.ingredients.filter {
            !setB.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private var uniqueToB: [String] {
        let setA = Set(scanA.ingredients.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        return scanB.ingredients.filter {
            !setA.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            themeManager.selectedTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    ratingCard
                    statsRow
                    categorySection
                    if !sharedIngredients.isEmpty {
                        ingredientsSection(
                            title: "Shared Ingredients",
                            badge: "\(sharedIngredients.count)",
                            icon: "arrow.triangle.merge",
                            color: themeManager.selectedTheme.colors.accent,
                            items: sharedIngredients
                        )
                    }
                    if !uniqueToA.isEmpty {
                        ingredientsSection(
                            title: "Only in \(scanA.itemName)",
                            badge: "\(uniqueToA.count)",
                            icon: "rectangle.lefthalf.filled",
                            color: .blue,
                            items: uniqueToA
                        )
                    }
                    if !uniqueToB.isEmpty {
                        ingredientsSection(
                            title: "Only in \(scanB.itemName)",
                            badge: "\(uniqueToB.count)",
                            icon: "rectangle.righthalf.filled",
                            color: .purple,
                            items: uniqueToB
                        )
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rating Comparison Card

    private var ratingCard: some View {
        HStack(alignment: .top, spacing: 0) {
            productColumn(scan: scanA)
            VStack {
                Spacer()
                Text("VS")
                    .font(.caption2).fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
            }
            .frame(width: 32)
            productColumn(scan: scanB)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    @ViewBuilder
    private func productColumn(scan: ScanModel) -> some View {
        VStack(spacing: 8) {
            Text(scan.itemName)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            ratingBadge(for: scan)

            Text("\(scan.ingredientCount) ingredient\(scan.ingredientCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func ratingBadge(for scan: ScanModel) -> some View {
        switch scan.healthCategory {
        case .food:
            if let gut = scan.gutPrediction {
                let (color, icon, label) = gutRating(gut.prediction)
                Label(label, systemImage: icon)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(color)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
        case .skin:
            if let skin = scan.skinPrediction {
                let (color, icon, label) = skinRating(skin.rating)
                Label(label, systemImage: icon)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(color)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
        case .nutrition:
            if let n = scan.nutritionFacts, n.calories > 0 {
                Text("\(Int(n.calories)) kcal")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private func gutRating(_ p: String) -> (Color, String, String) {
        let l = p.lowercased()
        if l.contains("gut friendly")  { return (.green,  "checkmark.seal.fill",             "Gut Friendly") }
        if l.contains("moderate risk") { return (.orange, "exclamationmark.triangle.fill",   "Moderate Risk") }
        return                                   (.red,    "xmark.octagon.fill",               "High Risk")
    }

    private func skinRating(_ r: String) -> (Color, String, String) {
        let l = r.lowercased()
        if l.contains("skin friendly")    { return (.green,  "leaf.fill",                         "Compatible") }
        if l.contains("moderate concern") { return (.orange, "exclamationmark.triangle.fill",     "Moderate") }
        return                                     (.red,    "xmark.octagon.fill",                 "High Concern")
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statPill(value: "\(scanA.ingredientCount)", label: scanA.itemName, color: .blue)
            Divider().frame(height: 36).overlay(Color.white.opacity(0.15))
            statPill(value: "\(sharedIngredients.count)", label: "shared", color: themeManager.selectedTheme.colors.accent)
            Divider().frame(height: 36).overlay(Color.white.opacity(0.15))
            statPill(value: "\(scanB.ingredientCount)", label: scanB.itemName, color: .purple)
        }
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category-Specific Section

    @ViewBuilder
    private var categorySection: some View {
        switch scanA.healthCategory {
        case .food:
            if let a = scanA.gutPrediction, let b = scanB.gutPrediction {
                comparisonCard(title: "Gut Health") {
                    if !a.triggers.isEmpty || !b.triggers.isEmpty {
                        flagRow(title: "Triggers", itemsA: a.triggers, itemsB: b.triggers, color: .red)
                    }
                    if !a.cautions.isEmpty || !b.cautions.isEmpty {
                        flagRow(title: "Cautions", itemsA: a.cautions, itemsB: b.cautions, color: .orange)
                    }
                    if a.triggers.isEmpty && b.triggers.isEmpty && a.cautions.isEmpty && b.cautions.isEmpty {
                        Text("No flagged ingredients in either scan.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        case .skin:
            if let a = scanA.skinPrediction, let b = scanB.skinPrediction {
                comparisonCard(title: "Skin Compatibility") {
                    if !a.irritants.isEmpty || !b.irritants.isEmpty {
                        flagRow(title: "Irritants", itemsA: a.irritants, itemsB: b.irritants, color: .red)
                    }
                    if !a.cautions.isEmpty || !b.cautions.isEmpty {
                        flagRow(title: "Cautions", itemsA: a.cautions, itemsB: b.cautions, color: .orange)
                    }
                    if a.irritants.isEmpty && b.irritants.isEmpty && a.cautions.isEmpty && b.cautions.isEmpty {
                        Text("No flagged ingredients in either scan.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        case .nutrition:
            if let a = scanA.nutritionFacts, let b = scanB.nutritionFacts {
                comparisonCard(title: "Nutrition") {
                    macroRow("Calories", a: a.calories,   b: b.calories,   unit: "kcal", lowerIsBetter: false)
                    macroRow("Protein",  a: a.proteinG,   b: b.proteinG,   unit: "g",    lowerIsBetter: false)
                    macroRow("Fat",      a: a.totalFatG,  b: b.totalFatG,  unit: "g",    lowerIsBetter: true)
                    macroRow("Carbs",    a: a.totalCarbsG,b: b.totalCarbsG,unit: "g",    lowerIsBetter: true)
                    macroRow("Sugar",    a: a.sugarG,     b: b.sugarG,     unit: "g",    lowerIsBetter: true)
                    macroRow("Sodium",   a: a.sodiumMg,   b: b.sodiumMg,   unit: "mg",   lowerIsBetter: true)
                }
            }
        }
    }

    private func comparisonCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline).fontWeight(.semibold)
                .foregroundStyle(.white)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    // MARK: - Flag Row (food & skin)

    private func flagRow(title: String, itemsA: [String], itemsB: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(color)
            }
            HStack(alignment: .top, spacing: 8) {
                chipGroup(items: itemsA, color: color)
                Divider().frame(maxHeight: 60).overlay(Color.white.opacity(0.15))
                chipGroup(items: itemsB, color: color)
            }
        }
    }

    @ViewBuilder
    private func chipGroup(items: [String], color: Color) -> some View {
        if items.isEmpty {
            Text("None")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FlowLayout(spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Macro Row (nutrition)

    private func macroRow(_ name: String, a: Double, b: Double, unit: String, lowerIsBetter: Bool) -> some View {
        let aWins = lowerIsBetter ? a <= b : a >= b
        let equal = a == b
        let aColor: Color = equal ? .white.opacity(0.65) : (aWins ? .green : Color.red.opacity(0.75))
        let bColor: Color = equal ? .white.opacity(0.65) : (!aWins ? .green : Color.red.opacity(0.75))

        return HStack {
            Text(numStr(a, unit: unit))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(aColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 64, alignment: .center)

            Text(numStr(b, unit: unit))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(bColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func numStr(_ value: Double, unit: String) -> String {
        guard value > 0 else { return "—" }
        return value == value.rounded() ? "\(Int(value))\(unit)" : String(format: "%.1f\(unit)", value)
    }

    // MARK: - Ingredients Section

    private func ingredientsSection(title: String, badge: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text(badge)
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }

            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(color.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }
}
