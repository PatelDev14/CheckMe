import SwiftUI
import SwiftData

struct NutritionScanView: View {
    @Query(
        filter: #Predicate<ScanModel> { $0.category == "Nutrition" },
        sort: \ScanModel.dateSaved,
        order: .reverse
    )
    private var scans: [ScanModel]

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @State private var showCamera = false
    @State private var lastScannedScan: ScanModel?
    @State private var navigateToLastScan = false
    @State private var searchText = ""
    @State private var scanToDelete: ScanModel?
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteConfirm = false
    @State private var showComparison = false
    @State private var compareScanA: ScanModel?
    @State private var compareScanB: ScanModel?

    private let accentColor = Color(red: 0.55, green: 0.45, blue: 0.95)

    private var filteredScans: [ScanModel] {
        guard !searchText.isEmpty else { return scans }
        return scans.filter { $0.itemName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                themeManager.selectedTheme.backgroundGradient.ignoresSafeArea()

                Group {
                    if scans.isEmpty { emptyState } else { scanList }
                }

                if isSelectMode { selectModeBar } else { scanFAB }
            }
            .navigationTitle("Nutrition")
            .searchable(text: $searchText, prompt: "Search scans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !scans.isEmpty {
                        Button(isSelectMode ? "Done" : "Select") {
                            withAnimation(.spring(response: 0.3)) {
                                isSelectMode.toggle()
                                selectedIDs.removeAll()
                            }
                        }
                        .fontWeight(isSelectMode ? .semibold : .regular)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToLastScan) {
                if let scan = lastScannedScan { NutritionResultsView(scan: scan) }
            }
            .navigationDestination(isPresented: $showComparison) {
                if let a = compareScanA, let b = compareScanB {
                    ScanComparisonView(scanA: a, scanB: b)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                NutritionCameraView { completedScan in
                    lastScannedScan = completedScan
                    navigateToLastScan = true
                }
            }
            .alert("Delete Scan?", isPresented: Binding(
                get: { scanToDelete != nil },
                set: { if !$0 { scanToDelete = nil } }
            )) {
                Button(role: .destructive) {
                    if let scan = scanToDelete { deleteScan(scan) }
                    scanToDelete = nil
                } label: { Text("Delete") }
                Button(role: .cancel) { scanToDelete = nil } label: { Text("Cancel") }
            } message: {
                if let scan = scanToDelete {
                    Text("Delete \(scan.itemName)? This cannot be undone.")
                }
            }
            .alert("Delete \(selectedIDs.count) Scan\(selectedIDs.count == 1 ? "" : "s")?",
                   isPresented: $showBulkDeleteConfirm) {
                Button(role: .destructive) { deleteSelected() } label: { Text("Delete") }
                Button(role: .cancel) {} label: { Text("Cancel") }
            } message: { Text("This cannot be undone.") }
        }
    }

    // MARK: - Scan List

    private var scanList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                statsRow

                if filteredScans.isEmpty {
                    noResultsView
                } else {
                    ForEach(filteredScans) { scan in
                        let isSelected = selectedIDs.contains(scan.persistentModelID)
                        if isSelectMode {
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    if isSelected { selectedIDs.remove(scan.persistentModelID) }
                                    else { selectedIDs.insert(scan.persistentModelID) }
                                }
                            } label: {
                                NutritionHistoryCard(scan: scan, isSelected: isSelected, isSelectMode: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: NutritionResultsView(scan: scan)) {
                                NutritionHistoryCard(scan: scan)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { scanToDelete = scan } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { scanToDelete = scan } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Select Mode Bottom Bar

    private var selectModeBar: some View {
        VStack(spacing: 0) {
            Divider().background(.white.opacity(0.1))
            HStack(spacing: 16) {
                if selectedIDs.isEmpty {
                    Text("Tap scans to select")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                } else {
                    Button {
                        selectedIDs = Set(filteredScans.map { $0.persistentModelID })
                    } label: {
                        Text("Select All")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    if selectedIDs.count == 2 {
                        Button {
                            let selected = filteredScans.filter { selectedIDs.contains($0.persistentModelID) }
                            if selected.count == 2 {
                                compareScanA = selected[0]
                                compareScanB = selected[1]
                                showComparison = true
                            }
                        } label: {
                            Label("Compare", systemImage: "rectangle.split.2x1")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(accentColor)
                        }
                        Divider()
                            .frame(height: 18)
                            .overlay(Color.white.opacity(0.3))
                    }
                    Button {
                        showBulkDeleteConfirm = true
                    } label: {
                        Label("Delete (\(selectedIDs.count))", systemImage: "trash")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            NutritionStatChip(value: "\(scans.count)", label: "Scans", icon: "camera.viewfinder", color: accentColor)
            NutritionStatChip(value: avgCaloriesText, label: "Avg Calories", icon: "flame.fill", color: .orange)
            NutritionStatChip(value: "\(highSodiumCount)", label: "High Sodium", icon: "drop.fill", color: .yellow)
        }
    }

    private var avgCaloriesText: String {
        let withData = scans.compactMap { $0.nutritionFacts?.calories }.filter { $0 > 0 }
        guard !withData.isEmpty else { return "—" }
        return "\(Int(withData.reduce(0, +) / Double(withData.count)))"
    }

    private var highSodiumCount: Int {
        // High sodium = > 30% of daily value (690mg)
        scans.filter { ($0.nutritionFacts?.sodiumMg ?? 0) > 690 }.count
    }

    // MARK: - Empty State (rich onboarding version)

    @State private var showSamplePreview = false

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(accentColor)
                    Text("See What's In Your Food")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Scan any Nutrition Facts panel for an instant macro breakdown and daily value analysis.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Mock Nutrition Facts label (like the muffin screenshot)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Example label to scan")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nutrition Facts")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.black)
                        Text("Per muffin (100 g)")
                            .font(.system(size: 10))
                            .foregroundStyle(.black.opacity(0.7))
                        Rectangle().fill(Color.black).frame(height: 7).padding(.vertical, 4)
                        HStack {
                            Text("Calories").font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                            Spacer()
                            Text("360").font(.system(size: 18, weight: .bold)).foregroundStyle(.black)
                        }
                        Rectangle().fill(Color.black.opacity(0.3)).frame(height: 0.5).padding(.vertical, 3)
                        nutritionRow("Fat / Lipides", "16 g", "21 %")
                        nutritionRow("Carbohydrate / Glucides", "49 g", "")
                        nutritionSubRow("  Sugars / Sucres", "27 g", "27 %")
                        nutritionRow("Protein / Protéines", "6 g", "")
                        nutritionRow("Sodium", "340 mg", "15 %")
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }

                // See example results button
                Button {
                    showSamplePreview = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill").font(.subheadline)
                        Text("See example results")
                            .font(.subheadline).fontWeight(.semibold)
                        Image(systemName: "arrow.right").font(.caption)
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(accentColor.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.35), lineWidth: 1))
                }
                .sheet(isPresented: $showSamplePreview) {
                    ExampleResultSheet(category: .nutrition)
                }

                // What to scan
                VStack(alignment: .leading, spacing: 12) {
                    Text("What to scan")
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.white)

                    ForEach([
                        ("bag.fill",               "Packaged Foods",        "Any product with a Nutrition Facts panel"),
                        ("birthday.cake.fill",     "Baked Goods & Snacks",  "Muffins, cookies, crackers — calories & macros"),
                        ("cup.and.saucer.fill",    "Breakfast Cereals",     "See sugar, fibre, and vitamin content at a glance"),
                        ("takeoutbag.and.cup.and.straw.fill", "Ready Meals","Frozen dinners, soups, meal kits"),
                    ], id: \.1) { icon, label, detail in
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label).font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))

                // Understanding results
                VStack(alignment: .leading, spacing: 12) {
                    Text("Understanding your results")
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.white)

                    ForEach([
                        ("flame.fill",    Color.orange, "Calories & Macros",   "Total calories, fat, carbs, protein per serving"),
                        ("chart.bar.fill",accentColor,  "Daily Value %",        "See how each nutrient stacks against your daily needs"),
                        ("drop.fill",     Color.yellow, "Key Nutrients",        "Sodium, sugar, fibre, vitamins and minerals"),
                    ], id: \.2) { icon, color, label, detail in
                        HStack(spacing: 14) {
                            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label).font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }

    private func nutritionRow(_ name: String, _ amount: String, _ dv: String) -> some View {
        HStack {
            Text(name).font(.system(size: 10)).foregroundStyle(.black)
            Spacer()
            Text(amount).font(.system(size: 10)).foregroundStyle(.black)
            if !dv.isEmpty {
                Text(dv).font(.system(size: 10, weight: .semibold)).foregroundStyle(.black).frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.vertical, 1)
    }

    private func nutritionSubRow(_ name: String, _ amount: String, _ dv: String) -> some View {
        HStack {
            Text(name).font(.system(size: 9)).foregroundStyle(.black.opacity(0.7))
            Spacer()
            Text(amount).font(.system(size: 9)).foregroundStyle(.black.opacity(0.7))
            Text(dv).font(.system(size: 9)).foregroundStyle(.black.opacity(0.7)).frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.title).foregroundStyle(.white.opacity(0.4))
            Text("No results for \(searchText)").font(.subheadline).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    // MARK: - FAB

    private var scanFAB: some View {
        Button { showCamera = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder").font(.headline)
                Text("Scan Nutrition Label").font(.headline).fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28).padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(accentColor)
                    .shadow(color: accentColor.opacity(0.5), radius: 12, y: 4)
            )
        }
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    private func deleteScan(_ scan: ScanModel) {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        modelContext.delete(scan)
        try? modelContext.save()
    }

    private func deleteSelected() {
        let toDelete = filteredScans.filter { selectedIDs.contains($0.persistentModelID) }
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        toDelete.forEach { modelContext.delete($0) }
        try? modelContext.save()
        withAnimation { selectedIDs.removeAll(); isSelectMode = false }
    }
}

// MARK: - History Card

struct NutritionHistoryCard: View {
    let scan: ScanModel
    var isSelected: Bool = false
    var isSelectMode: Bool = false
    @Environment(ThemeManager.self) private var themeManager

    private let accentColor = Color(red: 0.55, green: 0.45, blue: 0.95)

    var body: some View {
        HStack(spacing: 14) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : .white.opacity(0.4))
                    .animation(.spring(response: 0.2), value: isSelected)
            }

            ZStack {
                Circle().fill(accentColor.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: "chart.pie.fill").foregroundStyle(accentColor).font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.itemName)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    if let cal = scan.nutritionFacts?.calories, cal > 0 {
                        Label("\(Int(cal)) cal", systemImage: "flame.fill")
                            .font(.caption).foregroundStyle(.orange)
                        Text("·").foregroundStyle(.white.opacity(0.3))
                    }
                    if let fat = scan.nutritionFacts?.totalFatG {
                        Text("\(Int(fat))g fat").font(.caption).foregroundStyle(.white.opacity(0.5))
                        Text("·").foregroundStyle(.white.opacity(0.3))
                    }
                    Text(scan.dateSaved.dayDisplay).font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            if !isSelectMode {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(
            isSelected ? Color.blue.opacity(0.15) : themeManager.selectedTheme.colors.surface
        ))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            isSelected ? Color.blue.opacity(0.5) : .white.opacity(0.07),
            lineWidth: isSelected ? 1.5 : 1
        ))
    }
}

// MARK: - Stat Chip

private struct NutritionStatChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1))
    }
}
