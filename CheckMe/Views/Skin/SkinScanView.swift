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

    @State private var showCamera = false
    @State private var lastScannedScan: ScanModel?
    @State private var navigateToLastScan = false
    @State private var searchText = ""
    @State private var scanToDelete: ScanModel?

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
                    if scans.isEmpty {
                        emptyState
                    } else {
                        scanList
                    }
                }

                scanFAB
            }
            .navigationTitle("Skincare")
            .searchable(text: $searchText, prompt: "Search scans or ingredients")
            .navigationDestination(isPresented: $navigateToLastScan) {
                if let scan = lastScannedScan {
                    SkinResultsView(scan: scan)
                }
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
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatChipSkin(value: "\(scans.count)", label: "Scans", icon: "camera.viewfinder", color: themeManager.selectedTheme.colors.accent)
            StatChipSkin(value: "\(friendlyCount)", label: "Skin Friendly", icon: "leaf.fill", color: .green)
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
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(themeManager.selectedTheme.colors.accent.opacity(0.7))
            VStack(spacing: 8) {
                Text("No Skin Scans Yet")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Scan a skincare label to check if it's right for your skin.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
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
}

// MARK: - Skin History Card

struct SkinHistoryCard: View {
    let scan: ScanModel
    @Environment(ThemeManager.self) private var themeManager

    private var rating: (label: String, color: Color, icon: String) {
        guard let r = scan.skinPrediction?.rating.lowercased() else {
            return ("Not analysed", .gray, "questionmark.circle.fill")
        }
        if r.contains("skin friendly")    { return ("Skin Friendly",    .green,  "leaf.fill") }
        if r.contains("moderate concern") { return ("Moderate Concern", .orange, "exclamationmark.triangle.fill") }
        if r.contains("high concern")     { return ("High Concern",     .red,    "xmark.octagon.fill") }
        return ("Not analysed", .gray, "questionmark.circle.fill")
    }

    var body: some View {
        HStack(spacing: 14) {
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

            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.07), lineWidth: 1))
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

#Preview {
    SkinScanView()
        .modelContainer(for: [ScanModel.self, SkinIngredientModel.self], inMemory: true)
        .environment(FoundationModelsManager())
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
