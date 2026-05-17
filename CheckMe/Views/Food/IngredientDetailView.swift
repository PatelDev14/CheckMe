import SwiftUI
import SwiftData

// Deep-dive view for a single ingredient.
// Runs an AI analysis on first visit; caches the result in SwiftData so
// subsequent visits are instant regardless of whether Apple Intelligence is available.

struct IngredientDetailView: View {
    let ingredientName: String
    let scan: ScanModel

    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self) private var themeManager

    @State private var analysis: IngredientsModel?
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// True if this ingredient is in the scan's red "avoid" trigger list
    private var isTrigger: Bool {
        let triggers = scan.gutPrediction?.triggers ?? []
        let lower = ingredientName.lowercased()
        return triggers.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    /// True if this ingredient is in the scan's yellow "watch" caution list (and not already a trigger)
    private var isCaution: Bool {
        guard !isTrigger else { return false }
        let cautions = scan.gutPrediction?.cautions ?? []
        let lower = ingredientName.lowercased()
        return cautions.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    var body: some View {
        ZStack {
            themeManager.selectedTheme.colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header chip
                    ingredientHeader

                    if isLoading {
                        loadingCard
                    } else if let a = analysis {
                        // AI analysis cards
                        DetailCard(icon: "info.circle.fill", title: "What is it?", text: a.explanation)
                        // "arrow.triangle.2.circlepath" represents the digestive processing cycle
                        DetailCard(icon: "arrow.triangle.2.circlepath", title: "How does your body process it?", text: a.digestion)
                        DetailCard(icon: "figure.walk", title: "How does it feel?", text: a.digestiveFeel)

                        // Show appropriate warning card based on severity
                        if isTrigger {
                            flaggedWarningCard(
                                color: .red,
                                title: "Flagged as Avoid",
                                message: "CheckMe's gut analysis identified this as a significant concern based on your dietary profile. Consider avoiding this product."
                            )
                        } else if isCaution {
                            flaggedWarningCard(
                                color: .yellow,
                                title: "Flagged as Caution",
                                message: "CheckMe's gut analysis identified this as a mild concern worth monitoring. It may be fine in small amounts depending on your sensitivity."
                            )
                        }
                    } else if let error = errorMessage {
                        errorCard(message: error)
                    }

                    // Context banner — shows which product this came from
                    productContextBanner
                }
                .padding(16)
            }
        }
        .navigationTitle(ingredientName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAnalysis() }
    }

    // MARK: - Header

    private var ingredientHeader: some View {
        // Derive color/icon based on worst severity (trigger > caution > safe)
        let flagColor: Color = isTrigger ? .red : (isCaution ? .yellow : .white)
        let flagBackground: Color = isTrigger ? .red : (isCaution ? .yellow : .clear)
        let flagIcon: String = isTrigger ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack(spacing: 10) {
            if isTrigger || isCaution {
                Image(systemName: flagIcon)
                    .foregroundStyle(flagColor)
            }
            Text(ingredientName)
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(isTrigger || isCaution ? flagColor : .white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(
            Capsule().fill(
                (isTrigger || isCaution) ? flagBackground.opacity(0.12) : themeManager.selectedTheme.colors.surface
            )
        )
        .overlay(
            Capsule().stroke(
                (isTrigger || isCaution) ? flagColor.opacity(0.4) : Color.white.opacity(0.1),
                lineWidth: 1
            )
        )
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(themeManager.selectedTheme.colors.accent)
                .scaleEffect(1.3)
            Text("Analysing with Apple Intelligence…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text("This result will be cached for instant access next time.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    // MARK: - Flag Warning Card

    /// Renders a flag warning card in the appropriate colour for trigger (red) or caution (yellow).
    private func flaggedWarningCard(color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(color)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Error

    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Could not load analysis")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await loadAnalysis() }
            }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(themeManager.selectedTheme.colors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    // MARK: - Product Context

    private var productContextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "fork.knife.circle")
                .foregroundStyle(.white.opacity(0.4))
            Text("From: \(scan.itemName)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(scan.dateSaved.shortDisplay)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.selectedTheme.colors.surface.opacity(0.5)))
    }

    // MARK: - Data Loading

    private func loadAnalysis() async {
        guard analysis == nil else { return }  // already loaded
        isLoading = true
        errorMessage = nil
        do {
            let vm = IngredientsViewModel(modelContext: modelContext, profileStore: profileStore)
            analysis = try await vm.analyzeIngredient(ingredientName, in: scan)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Detail Card

private struct DetailCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}
