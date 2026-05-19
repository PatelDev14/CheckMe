import SwiftUI
import SwiftData

struct SkinScanView: View {
    @Query(
        filter: #Predicate<ScanModel> { $0.category == "Skin" },
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
    @State private var showSamplePreview = false

    private var filteredScans: [ScanModel] {
        guard !searchText.isEmpty else { return scans }
        return scans.filter { scan in
            scan.itemName.localizedCaseInsensitiveContains(searchText) ||
            scan.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                themeManager.selectedTheme.colors.background.ignoresSafeArea()

                Group {
                    if scans.isEmpty { emptyState } else { scanList }
                }

                if isSelectMode { selectModeBar } else { scanFAB }
            }
            .navigationTitle("Personal Care")
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
                if let scan = lastScannedScan { SkinResultsView(scan: scan) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                SkinCameraView { completedScan in
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
                                SkinHistoryCard(scan: scan, isSelected: isSelected, isSelectMode: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: SkinResultsView(scan: scan)) {
                                SkinHistoryCard(scan: scan)
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
            StatChipSkin(value: "\(scans.count)", label: "Scans", icon: "camera.viewfinder", color: themeManager.selectedTheme.colors.accent)
            StatChipSkin(value: "\(friendlyCount)", label: "Compatible", icon: "leaf.fill", color: .green)
            StatChipSkin(value: "\(concernCount)", label: "High Concern", icon: "xmark.octagon.fill", color: .red)
        }
    }

    private var friendlyCount: Int {
        scans.filter { $0.skinPrediction?.rating.lowercased().contains("skin friendly") == true }.count
    }

    private var concernCount: Int {
        scans.filter { $0.skinPrediction?.rating.lowercased().contains("high concern") == true }.count
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Hero
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.selectedTheme.colors.accent)
                    Text("Know What's On Your Skin")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Scan any personal care product to see if its ingredients suit your skin type and conditions.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Mock skin label preview (like the NIVEA label)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Example label to scan")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("NIVEA MEN ENERGY\nBODY WASH")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                        Divider().overlay(Color.white.opacity(0.3))
                        Text("Ingredients/Ingrédients:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Water/Eau, Sodium Laureth Sulfate, Cocamidopropyl Betaine, PEG-7 Glyceryl Cocoate, Parfum/Fragrance, Glycerin, Menthol, Polyquaternium-7, Alcohol Denat., Sodium Chloride, Citric Acid, Sodium Benzoate.")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.07, green: 0.13, blue: 0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                }

                // What you can scan
                VStack(alignment: .leading, spacing: 12) {
                    Text("What to scan")
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.white)

                    let scanExamples: [(icon: String, label: String, detail: String)] = [
                        ("drop.fill",         "Moisturisers & Serums", "Check for irritants & pore-cloggers"),
                        ("sun.max.fill",      "Sunscreens",            "Flag filters that may irritate sensitive skin"),
                        ("wind",              "Shampoo & Conditioner", "Detect sulfates & allergens"),
                        ("eyebrow",           "Makeup & Foundation",   "Avoid comedogenic pigments & preservatives"),
                    ]

                    ForEach(scanExamples, id: \.label) { example in
                        HStack(spacing: 14) {
                            Image(systemName: example.icon)
                                .font(.title3)
                                .foregroundStyle(themeManager.selectedTheme.colors.accent)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.label)
                                    .font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
                                Text(example.detail)
                                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))

                // What the ratings mean
                VStack(alignment: .leading, spacing: 12) {
                    Text("Understanding your results")
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.white)

                    ForEach([
                        ("leaf.fill",                    Color.green,  "Compatible",     "Minimal concerns for your skin profile"),
                        ("exclamationmark.triangle.fill", Color.orange, "Moderate Concern","1–2 ingredients worth watching"),
                        ("xmark.octagon.fill",            Color.red,    "High Concern",   "Known irritants or allergens for your skin"),
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
                    SampleResultPreviewSheet(category: .skin)
                }

                // Skin profile nudge — only shown if profile is empty
                if profileStore.profile.skinType.isEmpty && profileStore.profile.skinConditions.isEmpty {
                    SkinProfileNudgeBanner()
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title).foregroundStyle(.white.opacity(0.4))
            Text("No results for \(searchText)")
                .font(.subheadline).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - FAB

    private var scanFAB: some View {
        Button { showCamera = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder").font(.headline)
                Text("Scan Label").font(.headline).fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28).padding(.vertical, 16)
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

// MARK: - Skin History Card

struct SkinHistoryCard: View {
    let scan: ScanModel
    var isSelected: Bool = false
    var isSelectMode: Bool = false
    @Environment(ThemeManager.self) private var themeManager

    private var rating: (label: String, color: Color, icon: String) {
        guard let r = scan.skinPrediction?.rating.lowercased() else {
            return ("Not analysed", .gray, "questionmark.circle.fill")
        }
        if r.contains("skin friendly")    { return ("Compatible",       .green,  "leaf.fill") }
        if r.contains("moderate concern") { return ("Moderate Concern", .orange, "exclamationmark.triangle.fill") }
        if r.contains("high concern")     { return ("High Concern",     .red,    "xmark.octagon.fill") }
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
                Circle().fill(rating.color.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: rating.icon).foregroundStyle(rating.color).font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.itemName)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    Text(rating.label).font(.caption).fontWeight(.medium).foregroundStyle(rating.color)
                    Text("·").foregroundStyle(.white.opacity(0.3))
                    Text("\(scan.ingredientCount) ingredients").font(.caption).foregroundStyle(.white.opacity(0.5))
                    Text("·").foregroundStyle(.white.opacity(0.3))
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

private struct StatChipSkin: View {
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

// MARK: - Skin Profile Nudge Banner
// Shown in empty state AND at the top of results when skin profile is incomplete.

struct SkinProfileNudgeBanner: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showOnboarding = false

    var body: some View {
        Button { showOnboarding = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.62, green: 0.45, blue: 0.95))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Set your skin profile")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                    Text("Add your skin type and conditions for personalised irritant detection.")
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
                    .fill(Color(red: 0.62, green: 0.45, blue: 0.95).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 0.62, green: 0.45, blue: 0.95).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(startingStep: 3, isEditing: true)
                .environment(themeManager)
        }
    }
}

#Preview {
    SkinScanView()
        .modelContainer(for: [ScanModel.self, SkinIngredientModel.self], inMemory: true)
        .environment(FoundationModelsManager())
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
