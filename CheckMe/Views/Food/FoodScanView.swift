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

    @State private var showCamera = false
    @State private var lastScannedScan: ScanModel?
    @State private var navigateToLastScan = false
    @State private var searchText = ""
    @State private var scanToDelete: ScanModel?
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteConfirm = false

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
                themeManager.selectedTheme.colors.background
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

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(themeManager.selectedTheme.colors.accent.opacity(0.7))
            VStack(spacing: 8) {
                Text("No Food Scans Yet")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Scan an ingredient label to see if it's right for your gut.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
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

#Preview {
    FoodScanView()
        .modelContainer(for: [ScanModel.self, IngredientsModel.self], inMemory: true)
        .environment(FoundationModelsManager())
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
