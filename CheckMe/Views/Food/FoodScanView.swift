import SwiftUI
import SwiftData

// Home screen for the Food & Beverages category.
// Shows scan history as cards with gut rating badges, a search bar,
// and a prominent scan button that opens the full-screen camera.

struct FoodScanView: View {
    @Query(
        filter: #Predicate<ScanModel> { $0.category == "Food" },
        sort: \ScanModel.dateSaved,
        order: .reverse
    )
    private var scans: [ScanModel]

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore

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

    private var filteredScans: [ScanModel] {
        guard !searchText.isEmpty else { return scans }
        return scans.filter { scan in
            scan.itemName.localizedCaseInsensitiveContains(searchText) ||
            scan.ingredients.contains { ingredient in ingredient.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                themeManager.selectedTheme.backgroundGradient
                    .ignoresSafeArea()

                Group {
                    if scans.isEmpty {
                        emptyState
                    } else {
                        scanList
                    }
                }

                if isSelectMode {
                    selectModeBar
                } else {
                    scanFAB
                }
            }
            .navigationTitle("Food & Beverages")
            .searchable(text: $searchText, prompt: "Search scans or ingredients")
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
                if let scan = lastScannedScan {
                    IngredientsListView(scan: scan)
                }
            }
            .navigationDestination(isPresented: $showComparison) {
                if let a = compareScanA, let b = compareScanB {
                    ScanComparisonView(scanA: a, scanB: b)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { completedScan in
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
                Button(role: .destructive) { deleteSelected() } label: {
                    Text("Delete")
                }
                Button(role: .cancel) {} label: { Text("Cancel") }
            } message: {
                Text("This cannot be undone.")
            }
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
                                ScanHistoryCard(scan: scan, isSelected: isSelected, isSelectMode: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: IngredientsListView(scan: scan)) {
                                ScanHistoryCard(scan: scan)
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
                                .foregroundStyle(themeManager.selectedTheme.colors.accent)
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
            StatChip(
                value: "\(scans.count)",
                label: "Scans",
                icon: "camera.viewfinder",
                color: themeManager.selectedTheme.colors.accent
            )
            StatChip(
                value: "\(friendlyCount)",
                label: "Gut Friendly",
                icon: "checkmark.seal.fill",
                color: .green
            )
            StatChip(
                value: "\(riskyCount)",
                label: "High Risk",
                icon: "xmark.octagon.fill",
                color: .red
            )
        }
    }

    private var friendlyCount: Int {
        scans.filter { $0.gutPrediction?.prediction.lowercased().contains("gut friendly") == true }.count
    }

    private var riskyCount: Int {
        scans.filter { $0.gutPrediction?.prediction.lowercased().contains("high risk") == true }.count
    }

    // MARK: - Empty State (rich onboarding version)

    @State private var showSamplePreview = false

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.selectedTheme.colors.accent)
                    Text("Know What You're Eating")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Scan any ingredient label for instant gut-health analysis personalised to you.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Mock label preview (like the corn cereal screenshot)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Example label to scan")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingredients:")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                        Text("Whole grain corn, Sugars (sugar and/or golden sugar, corn syrup, golden syrup), Degermed corn meal, High monounsaturated canola and/or sunflower oil, Salt, Calcium carbonate, Caramel, Monoglycerides, Natural flavour (includes stevia leaf extract), Vitamins and minerals: Iron, Niacinamide (vitamin B3), Folate.")
                            .font(.system(size: 10))
                            .foregroundStyle(.black.opacity(0.75))
                            .lineLimit(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.1), lineWidth: 1))
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
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.accent.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(themeManager.selectedTheme.colors.accent.opacity(0.35), lineWidth: 1))
                }
                .sheet(isPresented: $showSamplePreview) {
                    ExampleResultSheet(category: .food)
                }

                // What to scan
                VStack(alignment: .leading, spacing: 12) {
                    Text("What to scan")
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.white)

                    ForEach([
                        ("bag.fill",              "Packaged Snacks",         "Chips, crackers, cookies — check for hidden triggers"),
                        ("mug.fill",              "Beverages & Drinks",      "Energy drinks, juices, plant milks"),
                        ("cart.fill",             "Supermarket Products",    "Any food with an ingredients list on the back"),
                        ("takeoutbag.and.cup.and.straw.fill", "Ready Meals", "Frozen meals, sauces, condiments"),
                    ], id: \.1) { icon, label, detail in
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(themeManager.selectedTheme.colors.accent)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label).font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))

                // Understanding results
                VStack(alignment: .leading, spacing: 12) {
                    Text("Understanding your results")
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.white)

                    ForEach([
                        ("checkmark.seal.fill",          Color.green,  "Gut Friendly",   "Minimal triggers for your gut profile"),
                        ("exclamationmark.triangle.fill", Color.orange, "Moderate Risk",  "1–2 ingredients worth monitoring"),
                        ("xmark.octagon.fill",            Color.red,    "High Risk",      "Known triggers or allergens for your profile"),
                    ], id: \.2) { icon, color, label, detail in
                        HStack(spacing: 14) {
                            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label).font(.subheadline).fontWeight(.semibold).foregroundStyle(color)
                                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))

                // Profile nudge — shown when food profile is empty
                let hasNoFoodProfile = profileStore.profile.foodRestrictions.isEmpty
                    && profileStore.profile.foodAllergies.isEmpty
                    && profileStore.profile.digestiveConditions.isEmpty
                if hasNoFoodProfile {
                    FoodProfileNudgeBanner()
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.white.opacity(0.4))
            Text("No results for \(searchText)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Floating Action Button

    private var scanFAB: some View {
        Button {
            showCamera = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.headline)
                Text("Scan Label")
                    .font(.headline).fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(themeManager.selectedTheme.colors.accent)
                    .shadow(color: themeManager.selectedTheme.colors.accent.opacity(0.5), radius: 12, y: 4)
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

// MARK: - Scan History Card

struct ScanHistoryCard: View {
    let scan: ScanModel
    var isSelected: Bool = false
    var isSelectMode: Bool = false
    @Environment(ThemeManager.self) private var themeManager

    private var rating: (label: String, color: Color, icon: String) {
        guard let p = scan.gutPrediction?.prediction.lowercased() else {
            return ("Not analysed", .gray, "questionmark.circle.fill")
        }
        if p.contains("gut friendly")  { return ("Gut Friendly",  .green,  "checkmark.seal.fill") }
        if p.contains("moderate risk") { return ("Moderate Risk", .orange, "exclamationmark.triangle.fill") }
        if p.contains("high risk")     { return ("High Risk",     .red,    "xmark.octagon.fill") }
        return ("Not analysed", .gray, "questionmark.circle.fill")
    }

    var body: some View {
        HStack(spacing: 14) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : .white.opacity(0.4))
                    .animation(.spring(response: 0.2), value: isSelected)
            }

            ZStack {
                Circle()
                    .fill(rating.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: rating.icon)
                    .foregroundStyle(rating.color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.itemName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(rating.label)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(rating.color)
                    Text("·").foregroundStyle(.white.opacity(0.3))
                    Text("\(scan.ingredientCount) ingredients")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                    Text("·").foregroundStyle(.white.opacity(0.3))
                    Text(scan.dateSaved.dayDisplay)
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            if !isSelectMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(
            isSelected
                ? Color.blue.opacity(0.15)
                : themeManager.selectedTheme.colors.surface
        ))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            isSelected ? Color.blue.opacity(0.5) : .white.opacity(0.07),
            lineWidth: isSelected ? 1.5 : 1
        ))
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            Text(value)
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Food Profile Nudge Banner

struct FoodProfileNudgeBanner: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showOnboarding = false

    var body: some View {
        Button { showOnboarding = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Set your food profile")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                    Text("Add your dietary preferences and allergies for personalised gut analysis.")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.selectedTheme.colors.accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(themeManager.selectedTheme.colors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(startingStep: 1, isEditing: true)
                .environment(themeManager)
        }
    }
}

#Preview {
    FoodScanView()
        .modelContainer(for: [ScanModel.self, IngredientsModel.self], inMemory: true)
        .environment(FoundationModelsManager())
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
