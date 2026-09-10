import SwiftUI
import SwiftData

// "Diary" tab — a daily nutrient & exposure diary.
// Shows aggregated macro/micronutrient totals (vs FDA daily values) for the
// selected day, plus a timeline of every LoggedEntry (food, nutrition, and
// personal-care logs) for that day with swipe-to-delete and a tap-through
// detail sheet.

struct DiaryView: View {
    @Query(sort: \LoggedEntry.timestamp, order: .reverse)
    private var allEntries: [LoggedEntry]

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showDatePicker = false
    @State private var selectedEntry: LoggedEntry?

    private var entriesForDay: [LoggedEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var nutritionEntries: [LoggedEntry] {
        entriesForDay.filter { $0.hasNutritionData }
    }

    // MARK: - Daily Totals

    private var totalCalories: Double { nutritionEntries.reduce(0) { $0 + $1.consumedCalories } }
    private var totalProteinG: Double { nutritionEntries.reduce(0) { $0 + $1.consumedProteinG } }
    private var totalCarbsG:   Double { nutritionEntries.reduce(0) { $0 + $1.consumedCarbsG } }
    private var totalFatG:     Double { nutritionEntries.reduce(0) { $0 + $1.consumedFatG } }
    private var totalSugarG:   Double { nutritionEntries.reduce(0) { $0 + $1.consumedSugarG } }
    private var totalFiberG:   Double { nutritionEntries.reduce(0) { $0 + $1.consumedFiberG } }
    private var totalSodiumMg: Double { nutritionEntries.reduce(0) { $0 + $1.consumedSodiumMg } }

    private let fatColor   = Color(red: 0.95, green: 0.55, blue: 0.10)
    private let carbColor  = Color(red: 0.25, green: 0.55, blue: 0.95)
    private let protColor  = Color(red: 0.20, green: 0.80, blue: 0.45)

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedThemeBackground(theme: themeManager.selectedTheme, pattern: .molecular)

                List {
                    Section {
                        dateNavHeader
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    if !nutritionEntries.isEmpty {
                        Section {
                            totalsCard
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }

                    if entriesForDay.isEmpty {
                        Section {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        Section("Timeline") {
                            ForEach(entriesForDay) { entry in
                                entryRow(entry)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            delete(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("Diary")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $selectedEntry) { entry in
                LoggedEntryDetailView(entry: entry)
                    .environment(themeManager)
            }
        }
    }

    // MARK: - Date Navigation

    private var dateNavHeader: some View {
        HStack {
            Button {
                changeDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(themeManager.selectedTheme.colors.surface))
            }

            Spacer()

            Button {
                showDatePicker = true
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dateTitle)
                            .font(.headline).fontWeight(.bold)
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(themeManager.selectedTheme.colors.accent)
                    }
                    if !Calendar.current.isDateInToday(selectedDate) {
                        Text("Tap to jump to a date")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            Button {
                changeDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(themeManager.selectedTheme.colors.surface))
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
            .opacity(Calendar.current.isDateInToday(selectedDate) ? 0.3 : 1)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: Binding(
                    get: { selectedDate },
                    set: { newValue in
                        selectedDate = Calendar.current.startOfDay(for: newValue)
                    }
                ),
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var dateTitle: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.dayDisplay
    }

    private func changeDay(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = newDate
            }
        }
    }

    // MARK: - Totals Card

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                calorieRing

                VStack(alignment: .leading, spacing: 12) {
                    macroBar(label: "Protein", value: totalProteinG, daily: NutritionDailyValues.proteinG, unit: "g", color: protColor)
                    macroBar(label: "Carbs",   value: totalCarbsG,   daily: NutritionDailyValues.totalCarbsG, unit: "g", color: carbColor)
                    macroBar(label: "Fat",     value: totalFatG,     daily: NutritionDailyValues.totalFatG, unit: "g", color: fatColor)
                }
            }

            Divider().overlay(.white.opacity(0.08))

            HStack(spacing: 0) {
                microStat(label: "Sugar",  value: totalSugarG,   unit: "g")
                microStat(label: "Fiber",  value: totalFiberG,   unit: "g")
                microStat(label: "Sodium", value: totalSodiumMg, unit: "mg")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.selectedTheme.colors.accent.opacity(0.2), lineWidth: 1))
    }

    private var calorieRing: some View {
        let progress = NutritionDailyValues.calories > 0
            ? min(totalCalories / NutritionDailyValues.calories, 1.0)
            : 0

        return ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 9)
                .frame(width: 88, height: 88)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(themeManager.selectedTheme.colors.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            VStack(spacing: 1) {
                Text("\(Int(totalCalories))")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("/ \(Int(NutritionDailyValues.calories)) cal")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func macroBar(label: String, value: Double, daily: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("\(Int(value))/\(Int(daily))\(unit)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: daily > 0 ? max(0, geo.size.width * min(value / daily, 1.0)) : 0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func microStat(label: String, value: Double, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value == value.rounded() ? "\(Int(value))\(unit)" : String(format: "%.1f%@", value, unit))
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline Row

    private func entryRow(_ entry: LoggedEntry) -> some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(entryIconColor(entry).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: entryIcon(entry))
                        .font(.subheadline)
                        .foregroundStyle(entryIconColor(entry))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.itemName)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))

                        if entry.hasNutritionData {
                            if !entry.mealType.isEmpty {
                                Text("· \(entry.mealType)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Text("· \(entry.portionLabel)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        } else if !entry.triggers.isEmpty {
                            Text("· \(entry.triggers.count) trigger\(entry.triggers.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.8))
                        } else if !entry.cautions.isEmpty {
                            Text("· \(entry.cautions.count) caution\(entry.cautions.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                }

                Spacer()

                if entry.hasNutritionData {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(entry.consumedCalories)) cal")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(themeManager.selectedTheme.colors.accent)
                        if !entry.allergens.isEmpty {
                            Label("Allergen", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 9)).fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                    }
                } else if !entry.gutRatingLabel.isEmpty {
                    let rating = GutRating(from: entry.gutRatingLabel)
                    Text(rating.label)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(rating.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(rating.color.opacity(0.15)))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(themeManager.selectedTheme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func entryIcon(_ entry: LoggedEntry) -> String {
        if entry.hasNutritionData, !entry.mealType.isEmpty {
            return mealTypeIcon(entry.mealType)
        }
        if !entry.gutRatingLabel.isEmpty {
            return GutRating(from: entry.gutRatingLabel).icon
        }
        return entry.healthCategory.systemImage
    }

    private func entryIconColor(_ entry: LoggedEntry) -> Color {
        if !entry.hasNutritionData, !entry.gutRatingLabel.isEmpty {
            return GutRating(from: entry.gutRatingLabel).color
        }
        return themeManager.selectedTheme.colors.accent
    }

    private func mealTypeIcon(_ mealType: String) -> String {
        switch mealType {
        case "Breakfast": return "sunrise.fill"
        case "Lunch":     return "sun.max.fill"
        case "Dinner":    return "moon.stars.fill"
        case "Snack":     return "carrot.fill"
        default:          return "chart.pie.fill"
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing logged yet")
                .font(.headline).fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("Scan a product, then tap “Log this product” to start your diary.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func delete(_ entry: LoggedEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

// MARK: - Entry Detail Sheet

private struct LoggedEntryDetailView: View {
    let entry: LoggedEntry

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    private let fatColor   = Color(red: 0.95, green: 0.55, blue: 0.10)
    private let carbColor  = Color(red: 0.25, green: 0.55, blue: 0.95)
    private let protColor  = Color(red: 0.20, green: 0.80, blue: 0.45)

    private var microStats: [(label: String, value: Double, unit: String, daily: Double)] {
        [
            ("Sat. Fat",   entry.consumedSaturatedFatG, "g",   NutritionDailyValues.saturatedFatG),
            ("Sodium",     entry.consumedSodiumMg,      "mg",  NutritionDailyValues.sodiumMg),
            ("Potassium",  entry.consumedPotassiumMg,   "mg",  NutritionDailyValues.potassiumMg),
            ("Calcium",    entry.consumedCalciumMg,     "mg",  NutritionDailyValues.calciumMg),
            ("Iron",       entry.consumedIronMg,        "mg",  NutritionDailyValues.ironMg),
            ("Vitamin D",  entry.consumedVitaminDMcg,   "mcg", NutritionDailyValues.vitaminDMcg),
            ("Vitamin A",  entry.consumedVitaminAMcg,   "mcg", NutritionDailyValues.vitaminAMcg),
            ("Vitamin C",  entry.consumedVitaminCMg,    "mg",  NutritionDailyValues.vitaminCMg),
        ].filter { $0.value > 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedThemeBackground(theme: themeManager.selectedTheme, pattern: .molecular)

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        if entry.hasNutritionData {
                            nutritionSummaryCard
                            if !microStats.isEmpty {
                                microNutrientsCard
                            }
                            if !entry.allergens.isEmpty {
                                allergensCard
                            }
                        } else {
                            gutSnapshotCard
                        }

                        if let scan = entry.scan {
                            viewScanLink(scan)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Logged Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(entry.itemName)
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            if entry.hasNutritionData {
                HStack(spacing: 8) {
                    if !entry.mealType.isEmpty {
                        Label(entry.mealType, systemImage: "fork.knife")
                    }
                    Label("\(entry.portionLabel) of \(entry.servingSize)", systemImage: "scalemass")
                }
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(themeManager.selectedTheme.colors.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Nutrition Summary

    private var nutritionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                calorieRing

                VStack(alignment: .leading, spacing: 12) {
                    macroBar(label: "Protein", value: entry.consumedProteinG, daily: NutritionDailyValues.proteinG, unit: "g", color: protColor)
                    macroBar(label: "Carbs",   value: entry.consumedCarbsG,   daily: NutritionDailyValues.totalCarbsG, unit: "g", color: carbColor)
                    macroBar(label: "Fat",     value: entry.consumedFatG,     daily: NutritionDailyValues.totalFatG, unit: "g", color: fatColor)
                }
            }

            Divider().overlay(.white.opacity(0.08))

            HStack(spacing: 0) {
                microStat(label: "Sugar", value: entry.consumedSugarG, unit: "g")
                microStat(label: "Fiber", value: entry.consumedFiberG, unit: "g")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.selectedTheme.colors.accent.opacity(0.2), lineWidth: 1))
    }

    private var calorieRing: some View {
        let progress = NutritionDailyValues.calories > 0
            ? min(entry.consumedCalories / NutritionDailyValues.calories, 1.0)
            : 0

        return ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 9)
                .frame(width: 88, height: 88)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(themeManager.selectedTheme.colors.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int(entry.consumedCalories))")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("/ \(Int(NutritionDailyValues.calories)) cal")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func macroBar(label: String, value: Double, daily: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("\(Int(value))/\(Int(daily))\(unit)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: daily > 0 ? max(0, geo.size.width * min(value / daily, 1.0)) : 0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func microStat(label: String, value: Double, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value == value.rounded() ? "\(Int(value))\(unit)" : String(format: "%.1f%@", value, unit))
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Micronutrients

    private var microNutrientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Micronutrients")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(microStats, id: \.label) { stat in
                    VStack(spacing: 3) {
                        Text(stat.value == stat.value.rounded() ? "\(Int(stat.value))\(stat.unit)" : String(format: "%.1f%@", stat.value, stat.unit))
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text(stat.label)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(stat.daily > 0 ? "\(Int((stat.value / stat.daily * 100).rounded()))% DV" : "")
                            .font(.system(size: 9))
                            .foregroundStyle(themeManager.selectedTheme.colors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Allergens

    private var allergensCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Allergens")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            FlowLayout(spacing: 6) {
                ForEach(entry.allergens, id: \.self) { allergen in
                    Text(allergen)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(.orange.opacity(0.15)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Gut Snapshot (Food / Personal Care logs)

    private var gutSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !entry.gutRatingLabel.isEmpty {
                let rating = GutRating(from: entry.gutRatingLabel)
                HStack(spacing: 10) {
                    Image(systemName: rating.icon)
                        .font(.title2)
                        .foregroundStyle(rating.color)
                    Text(rating.label)
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(rating.color)
                    Spacer()
                }
            }

            if !entry.triggers.isEmpty {
                chipSection(title: "Triggers", items: entry.triggers, color: .red)
            }

            if !entry.cautions.isEmpty {
                chipSection(title: "Cautions", items: entry.cautions, color: .orange)
            }

            if entry.gutRatingLabel.isEmpty && entry.triggers.isEmpty && entry.cautions.isEmpty {
                Text("No gut analysis was available for this product when it was logged.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.selectedTheme.colors.accent.opacity(0.2), lineWidth: 1))
    }

    private func chipSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
            FlowLayout(spacing: 6) {
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
        }
    }

    // MARK: - View Scan Link

    @ViewBuilder
    private func viewScanLink(_ scan: ScanModel) -> some View {
        NavigationLink {
            switch entry.healthCategory {
            case .food:      IngredientsListView(scan: scan)
            case .nutrition: NutritionResultsView(scan: scan)
            case .skin:      SkinResultsView(scan: scan)
            }
        } label: {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("View Original Scan")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeManager.selectedTheme.colors.accent.opacity(0.2), lineWidth: 1))
        }
    }
}

#Preview {
    DiaryView()
        .modelContainer(for: [ScanModel.self, LoggedEntry.self], inMemory: true)
        .environment(ThemeManager())
}
