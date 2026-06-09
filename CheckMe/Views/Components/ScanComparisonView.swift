import SwiftUI

/// Side-by-side comparison of two scans from the same category.
/// Triggered from select-mode bottom bar when exactly 2 scans are chosen.
struct ScanComparisonView: View {
    let scanA: ScanModel
    let scanB: ScanModel

    @Environment(ThemeManager.self) private var themeManager

    // MARK: - Ingredient overlap

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
    private var overlapPct: Int {
        let total = scanA.ingredientCount + scanB.ingredientCount
        guard total > 0 else { return 0 }
        return Int(Double(sharedIngredients.count * 2) / Double(total) * 100)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AnimatedThemeBackground(theme: themeManager.selectedTheme)

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

    // MARK: - Rating Card

    private var ratingCard: some View {
        HStack(alignment: .top, spacing: 0) {
            productColumn(scan: scanA)
            VStack(spacing: 4) {
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

            Text(scan.dateSaved.shortDisplay)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.28))
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

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statPill(value: "\(scanA.ingredientCount)", label: scanA.itemName, color: .blue)
            Divider().frame(height: 36).overlay(Color.white.opacity(0.15))
            VStack(spacing: 2) {
                statPill(value: "\(sharedIngredients.count)", label: "shared", color: themeManager.selectedTheme.colors.accent)
                Text("\(overlapPct)% overlap")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.28))
            }
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
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    // MARK: - Category Section

    @ViewBuilder
    private var categorySection: some View {
        switch scanA.healthCategory {

        // ── Food ────────────────────────────────────────────────────────────────
        case .food:
            if let a = scanA.gutPrediction, let b = scanB.gutPrediction {

                // Healthiness verdict
                let aFlags = a.triggers.count + a.cautions.count
                let bFlags = b.triggers.count + b.cautions.count
                verdictCard(
                    winnerName: aFlags <= bFlags ? scanA.itemName : scanB.itemName,
                    reason: aFlags == bFlags
                        ? "Both products have the same number of flagged ingredients."
                        : "\(aFlags <= bFlags ? scanA.itemName : scanB.itemName) has fewer flagged ingredients (\(min(aFlags, bFlags)) vs \(max(aFlags, bFlags))).",
                    icon: "heart.fill",
                    color: .green
                )

                // Flags comparison
                comparisonCard(title: "Gut Health", icon: "stomach") {
                    flagIntensityRow(
                        labelA: "\(a.triggers.count) trigger\(a.triggers.count == 1 ? "" : "s") · \(a.cautions.count) caution\(a.cautions.count == 1 ? "" : "s")",
                        labelB: "\(b.triggers.count) trigger\(b.triggers.count == 1 ? "" : "s") · \(b.cautions.count) caution\(b.cautions.count == 1 ? "" : "s")",
                        scoreA: aFlags, scoreB: bFlags, lowerIsBetter: true
                    )
                    if !a.triggers.isEmpty || !b.triggers.isEmpty {
                        flagRow(title: "Triggers", itemsA: a.triggers, itemsB: b.triggers, color: .red)
                    }
                    if !a.cautions.isEmpty || !b.cautions.isEmpty {
                        flagRow(title: "Cautions", itemsA: a.cautions, itemsB: b.cautions, color: .orange)
                    }
                    if a.triggers.isEmpty && b.triggers.isEmpty && a.cautions.isEmpty && b.cautions.isEmpty {
                        Text("No flagged ingredients in either scan.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.45))
                    }
                }

                // Tips
                if !a.tip.isEmpty || !b.tip.isEmpty {
                    tipComparisonCard(tipA: a.tip, tipB: b.tip, icon: "lightbulb.fill")
                }
            }

        // ── Skin ─────────────────────────────────────────────────────────────────
        case .skin:
            if let a = scanA.skinPrediction, let b = scanB.skinPrediction {

                let aFlags = a.irritants.count + a.cautions.count
                let bFlags = b.irritants.count + b.cautions.count
                verdictCard(
                    winnerName: aFlags <= bFlags ? scanA.itemName : scanB.itemName,
                    reason: aFlags == bFlags
                        ? "Both products have the same number of flagged ingredients for your skin."
                        : "\(aFlags <= bFlags ? scanA.itemName : scanB.itemName) has fewer skin concerns (\(min(aFlags, bFlags)) vs \(max(aFlags, bFlags))).",
                    icon: "face.smiling",
                    color: .pink
                )

                // Flag comparison
                comparisonCard(title: "Skin Compatibility", icon: "allergens") {
                    flagIntensityRow(
                        labelA: "\(a.irritants.count) irritant\(a.irritants.count == 1 ? "" : "s") · \(a.cautions.count) caution\(a.cautions.count == 1 ? "" : "s")",
                        labelB: "\(b.irritants.count) irritant\(b.irritants.count == 1 ? "" : "s") · \(b.cautions.count) caution\(b.cautions.count == 1 ? "" : "s")",
                        scoreA: aFlags, scoreB: bFlags, lowerIsBetter: true
                    )
                    if !a.irritants.isEmpty || !b.irritants.isEmpty {
                        flagRow(title: "Irritants", itemsA: a.irritants, itemsB: b.irritants, color: .red)
                    }
                    if !a.cautions.isEmpty || !b.cautions.isEmpty {
                        flagRow(title: "Cautions", itemsA: a.cautions, itemsB: b.cautions, color: .orange)
                    }
                    if a.irritants.isEmpty && b.irritants.isEmpty && a.cautions.isEmpty && b.cautions.isEmpty {
                        Text("No flagged ingredients in either scan.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.45))
                    }
                }

                // Functional ingredient breakdown
                if let catA = scanA.skinCategories, let catB = scanB.skinCategories {
                    let dictA = Dictionary(uniqueKeysWithValues: catA.decoded().map { ($0.category, $0.ingredients.count) })
                    let dictB = Dictionary(uniqueKeysWithValues: catB.decoded().map { ($0.category, $0.ingredients.count) })
                    comparisonCard(title: "What's in the formula", icon: "flask.fill") {
                        skinCategoryRow("Actives",      a: dictA["Actives", default: 0],      b: dictB["Actives", default: 0],      icon: "sparkles",        color: .purple)
                        skinCategoryRow("Humectants",   a: dictA["Humectants", default: 0],   b: dictB["Humectants", default: 0],   icon: "drop.fill",       color: .blue)
                        skinCategoryRow("Emollients",   a: dictA["Emollients", default: 0],   b: dictB["Emollients", default: 0],   icon: "hands.sparkles",  color: .teal)
                        skinCategoryRow("Occlusives",   a: dictA["Occlusives", default: 0],   b: dictB["Occlusives", default: 0],   icon: "shield.fill",     color: .gray)
                        skinCategoryRow("Preservatives",a: dictA["Preservatives", default: 0],b: dictB["Preservatives", default: 0],icon: "cross.vial.fill", color: .orange)
                        skinCategoryRow("Fragrances",   a: dictA["Fragrances", default: 0],   b: dictB["Fragrances", default: 0],   icon: "wind",            color: .yellow, lowerIsBetter: true)
                        skinCategoryRow("Surfactants",  a: dictA["Surfactants", default: 0],  b: dictB["Surfactants", default: 0],  icon: "bubbles.and.sparkles.fill", color: .cyan)
                    }
                }

                // Tips
                if !a.tip.isEmpty || !b.tip.isEmpty {
                    tipComparisonCard(tipA: a.tip, tipB: b.tip, icon: "lightbulb.fill")
                }
            }

        // ── Nutrition ─────────────────────────────────────────────────────────────
        case .nutrition:
            if let a = scanA.nutritionFacts, let b = scanB.nutritionFacts {

                // Winner tally
                nutritionWinnerCard(a: a, b: b)

                // Macro numbers
                comparisonCard(title: "Nutrition Facts", icon: "chart.pie.fill") {
                    servingSizeRow(a.servingSize, b.servingSize)
                    Divider().overlay(Color.white.opacity(0.10))
                    macroRow("Calories", a: a.calories,    b: b.calories,    daily: 2000, unit: "kcal", lowerIsBetter: false)
                    macroRow("Protein",  a: a.proteinG,    b: b.proteinG,    daily: 50,   unit: "g",    lowerIsBetter: false)
                    macroRow("Fiber",    a: a.fiberG,      b: b.fiberG,      daily: 28,   unit: "g",    lowerIsBetter: false)
                    macroRow("Fat",      a: a.totalFatG,   b: b.totalFatG,   daily: 78,   unit: "g",    lowerIsBetter: true)
                    macroRow("Carbs",    a: a.totalCarbsG, b: b.totalCarbsG, daily: 275,  unit: "g",    lowerIsBetter: true)
                    macroRow("Sugar",    a: a.sugarG,      b: b.sugarG,      daily: 50,   unit: "g",    lowerIsBetter: true)
                    macroRow("Sodium",   a: a.sodiumMg,    b: b.sodiumMg,    daily: 2300, unit: "mg",   lowerIsBetter: true)
                    macroRow("Potassium",a: a.potassiumMg, b: b.potassiumMg, daily: 4700, unit: "mg",   lowerIsBetter: false)
                }

                // Macro balance side by side
                miniMacroBalanceCard(a: a, b: b)

                // AI insights
                if !a.aiInsight.isEmpty || !b.aiInsight.isEmpty {
                    tipComparisonCard(tipA: a.aiInsight, tipB: b.aiInsight, icon: "sparkles")
                }
            }
        }
    }

    // MARK: - Verdict Card

    private func verdictCard(winnerName: String, reason: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Better Choice")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(color)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(winnerName)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(reason)
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Flag Intensity Row

    private func flagIntensityRow(labelA: String, labelB: String, scoreA: Int, scoreB: Int, lowerIsBetter: Bool) -> some View {
        let aWins = lowerIsBetter ? scoreA <= scoreB : scoreA >= scoreB
        let aColor: Color = scoreA == scoreB ? .white.opacity(0.5) : (aWins ? .green : .red.opacity(0.75))
        let bColor: Color = scoreA == scoreB ? .white.opacity(0.5) : (!aWins ? .green : .red.opacity(0.75))
        return HStack(alignment: .top) {
            Label(labelA, systemImage: aWins && scoreA != scoreB ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(aColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Label(labelB, systemImage: !aWins && scoreA != scoreB ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(bColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tip Comparison Card

    private func tipComparisonCard(tipA: String, tipB: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.yellow)
                Text("Recommendations")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            HStack(alignment: .top, spacing: 12) {
                tipBubble(text: tipA, color: .blue)
                tipBubble(text: tipB, color: .purple)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    private func tipBubble(text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text.isEmpty ? "No tip available." : text)
                .font(.caption)
                .foregroundStyle(text.isEmpty ? .white.opacity(0.3) : .white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Skin Category Row

    private func skinCategoryRow(_ name: String, a: Int, b: Int, icon: String, color: Color, lowerIsBetter: Bool = false) -> some View {
        let aWins = lowerIsBetter ? a <= b : a >= b
        let equal = a == b
        let aColor: Color = equal ? .white.opacity(0.55) : (aWins ? .green : .white.opacity(0.55))
        let bColor: Color = equal ? .white.opacity(0.55) : (!aWins ? .green : .white.opacity(0.55))
        return HStack {
            HStack(spacing: 4) {
                Text("\(a)").font(.subheadline).fontWeight(.semibold).foregroundStyle(aColor)
                if !equal && aWins { Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2).foregroundStyle(color)
                Text(name).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 110, alignment: .center)

            HStack(spacing: 4) {
                if !equal && !aWins { Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green) }
                Text("\(b)").font(.subheadline).fontWeight(.semibold).foregroundStyle(bColor)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Nutrition Winner Card

    private func nutritionWinnerCard(a: SavedNutritionFacts, b: SavedNutritionFacts) -> some View {
        // Count wins per product (8 nutrients)
        let rows: [(aVal: Double, bVal: Double, lowerIsBetter: Bool)] = [
            (a.calories,    b.calories,    false),
            (a.proteinG,    b.proteinG,    false),
            (a.fiberG,      b.fiberG,      false),
            (a.totalFatG,   b.totalFatG,   true),
            (a.totalCarbsG, b.totalCarbsG, true),
            (a.sugarG,      b.sugarG,      true),
            (a.sodiumMg,    b.sodiumMg,    true),
            (a.potassiumMg, b.potassiumMg, false),
        ]
        var aWins = 0; var bWins = 0
        for row in rows {
            guard row.aVal > 0 || row.bVal > 0 else { continue }
            if row.aVal == row.bVal { continue }
            if row.lowerIsBetter { row.aVal < row.bVal ? (aWins += 1) : (bWins += 1) }
            else                 { row.aVal > row.bVal ? (aWins += 1) : (bWins += 1) }
        }
        let totalJudged = aWins + bWins
        let winnerName  = aWins >= bWins ? scanA.itemName : scanB.itemName
        let winnerScore = max(aWins, bWins)
        let winnerColor: Color = aWins >= bWins ? .blue : .purple

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(winnerColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "trophy.fill").foregroundStyle(winnerColor).font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Nutritionally stronger").font(.caption).fontWeight(.semibold)
                    .foregroundStyle(winnerColor).textCase(.uppercase).tracking(0.5)
                Text(winnerName).font(.subheadline).fontWeight(.bold).foregroundStyle(.white).lineLimit(2)
                Text("Wins \(winnerScore) out of \(totalJudged) nutrient categories")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            // Mini score pills
            VStack(spacing: 4) {
                scorePill(value: aWins, color: .blue)
                scorePill(value: bWins, color: .purple)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(winnerColor.opacity(0.3), lineWidth: 1))
    }

    private func scorePill(value: Int, color: Color) -> some View {
        Text("\(value) wins")
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Mini Macro Balance (side by side)

    private func miniMacroBalanceCard(a: SavedNutritionFacts, b: SavedNutritionFacts) -> some View {
        let fatColor  = Color(red: 0.95, green: 0.55, blue: 0.10)
        let carbColor = Color(red: 0.25, green: 0.55, blue: 0.95)
        let protColor = Color(red: 0.20, green: 0.80, blue: 0.45)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                Text("Calorie Split")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            // Legend
            HStack(spacing: 14) {
                legendDot(color: fatColor, label: "Fat")
                legendDot(color: carbColor, label: "Carbs")
                legendDot(color: protColor, label: "Protein")
                Spacer()
            }
            // Two bars
            VStack(spacing: 8) {
                miniBar(label: scanA.itemName, nutrition: a, fatColor: fatColor, carbColor: carbColor, protColor: protColor, nameColor: .blue)
                miniBar(label: scanB.itemName, nutrition: b, fatColor: fatColor, carbColor: carbColor, protColor: protColor, nameColor: .purple)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.5))
        }
    }

    private func miniBar(label: String, nutrition: SavedNutritionFacts, fatColor: Color, carbColor: Color, protColor: Color, nameColor: Color) -> some View {
        let fatCal  = nutrition.totalFatG   * 9
        let carbCal = nutrition.totalCarbsG * 4
        let protCal = nutrition.proteinG    * 4
        let total   = fatCal + carbCal + protCal
        guard total > 0 else { return AnyView(EmptyView()) }
        let fatPct  = CGFloat(fatCal  / total)
        let carbPct = CGFloat(carbCal / total)
        let protPct = CGFloat(protCal / total)
        return AnyView(HStack(spacing: 8) {
            Text(label)
                .font(.caption2).fontWeight(.medium)
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width - 4
                HStack(spacing: 2) {
                    if fatPct > 0.01 {
                        RoundedRectangle(cornerRadius: 2).fill(fatColor)
                            .frame(width: max(0, w * fatPct), height: 12)
                    }
                    if carbPct > 0.01 {
                        RoundedRectangle(cornerRadius: 2).fill(carbColor)
                            .frame(width: max(0, w * carbPct), height: 12)
                    }
                    if protPct > 0.01 {
                        RoundedRectangle(cornerRadius: 2).fill(protColor)
                            .frame(width: max(0, w * protPct), height: 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 12)
            Text("\(Int(nutrition.calories)) cal")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 44, alignment: .trailing)
        })
    }

    // MARK: - Comparison Card (generic container)

    private func comparisonCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline).foregroundStyle(themeManager.selectedTheme.colors.accent)
                Text(title).font(.headline).fontWeight(.semibold).foregroundStyle(.white)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    // MARK: - Flag Row (food & skin chips)

    private func flagRow(title: String, itemsA: [String], itemsB: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(color)
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
                .font(.caption).foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FlowLayout(spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Serving Size Row

    private func servingSizeRow(_ sizeA: String, _ sizeB: String) -> some View {
        HStack(alignment: .top) {
            Text(sizeA)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Per Serving")
                .font(.caption2).foregroundStyle(.white.opacity(0.45))
                .frame(width: 72, alignment: .center)
                .multilineTextAlignment(.center)

            Text(sizeB)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Macro Row (with % DV)

    private func macroRow(_ name: String, a: Double, b: Double, daily: Double, unit: String, lowerIsBetter: Bool) -> some View {
        let aWins = lowerIsBetter ? a <= b : a >= b
        let equal = a == b
        let aColor: Color = equal ? .white.opacity(0.65) : (aWins ? .green : Color.red.opacity(0.75))
        let bColor: Color = equal ? .white.opacity(0.65) : (!aWins ? .green : Color.red.opacity(0.75))
        let aDV = daily > 0 && a > 0 ? Int((a / daily) * 100) : -1
        let bDV = daily > 0 && b > 0 ? Int((b / daily) * 100) : -1

        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(a > 0 ? numStr(a, unit: unit) : "—")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(aColor)
                if aDV >= 0 {
                    Text("\(aDV)% DV").font(.caption2).foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(name)
                .font(.caption).foregroundStyle(.white.opacity(0.45))
                .frame(width: 64, alignment: .center)

            VStack(alignment: .trailing, spacing: 1) {
                Text(b > 0 ? numStr(b, unit: unit) : "—")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(bColor)
                if bDV >= 0 {
                    Text("\(bDV)% DV").font(.caption2).foregroundStyle(.white.opacity(0.35))
                }
            }
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
                Image(systemName: icon).font(.subheadline).foregroundStyle(color)
                Text(title).font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                Spacer()
                Text(badge)
                    .font(.caption).fontWeight(.bold).foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.15)).clipShape(Capsule())
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

    // MARK: - Helpers

    private func gutRating(_ p: String) -> (Color, String, String) {
        let l = p.lowercased()
        if l.contains("gut friendly")  { return (.green,  "checkmark.seal.fill",           "Gut Friendly") }
        if l.contains("moderate risk") { return (.orange, "exclamationmark.triangle.fill", "Moderate Risk") }
        return                                   (.red,    "xmark.octagon.fill",             "High Risk")
    }

    private func skinRating(_ r: String) -> (Color, String, String) {
        let l = r.lowercased()
        if l.contains("skin friendly")    { return (.green,  "leaf.fill",                       "Compatible") }
        if l.contains("moderate concern") { return (.orange, "exclamationmark.triangle.fill",   "Moderate") }
        return                                     (.red,    "xmark.octagon.fill",               "High Concern")
    }
}
