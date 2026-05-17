import SwiftUI
import SwiftData

struct SkinIngredientDetailView: View {
    let ingredientName: String
    let scan: ScanModel

    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self) private var themeManager

    @State private var analysis: SkinIngredientModel?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isIrritant: Bool {
        let irritants = scan.skinPrediction?.irritants ?? []
        let lower = ingredientName.lowercased()
        return irritants.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    private var isCaution: Bool {
        guard !isIrritant else { return false }
        let cautions = scan.skinPrediction?.cautions ?? []
        let lower = ingredientName.lowercased()
        return cautions.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    var body: some View {
        ZStack {
            themeManager.selectedTheme.colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    ingredientHeader

                    if isLoading {
                        loadingCard
                    } else if let a = analysis {
                        SkinDetailCard(icon: "info.circle.fill", title: "What is it?", text: a.explanation)
                        SkinDetailCard(icon: "sparkles", title: "How does your skin react?", text: a.skinEffect)
                        SkinDetailCard(icon: "person.fill.checkmark", title: "Is it right for your skin?", text: a.suitability)

                        if isIrritant {
                            flaggedWarningCard(
                                color: .red,
                                title: "Flagged as Irritant",
                                message: "CheckMe's skin analysis identified this as a significant concern for your skin profile. Consider avoiding this product or patch testing first."
                            )
                        } else if isCaution {
                            flaggedWarningCard(
                                color: .yellow,
                                title: "Flagged as Caution",
                                message: "CheckMe's skin analysis identified this as a mild concern. It may be fine for your skin in small amounts, but monitor for any reaction."
                            )
                        }
                    } else if let error = errorMessage {
                        errorCard(message: error)
                    }

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
        let flagColor: Color = isIrritant ? .red : (isCaution ? .yellow : .white)
        let flagBackground: Color = isIrritant ? .red : (isCaution ? .yellow : .clear)
        let flagIcon: String = isIrritant ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                if isIrritant || isCaution {
                    Image(systemName: flagIcon)
                        .foregroundStyle(flagColor)
                        .frame(width: 18, height: 18)
                }
                Text(ingredientName)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(isIrritant || isCaution ? flagColor : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16).fill(
                (isIrritant || isCaution) ? flagBackground.opacity(0.12) : themeManager.selectedTheme.colors.surface
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(
                (isIrritant || isCaution) ? flagColor.opacity(0.4) : Color.white.opacity(0.1),
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

    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title).foregroundStyle(.orange)
            Text("Could not load analysis")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
            Text(message)
                .font(.caption).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Try Again") { Task { await loadAnalysis() } }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(themeManager.selectedTheme.colors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    private var productContextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.white.opacity(0.4))
            Text("From: \(scan.itemName)")
                .font(.caption).foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(scan.dateSaved.shortDisplay)
                .font(.caption).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.selectedTheme.colors.surface.opacity(0.5)))
    }

    // MARK: - Data Loading

    private func loadAnalysis() async {
        guard analysis == nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            let vm = SkinViewModel(modelContext: modelContext, profileStore: profileStore)
            analysis = try await vm.analyzeSkinIngredient(ingredientName, in: scan)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Skin Detail Card

private struct SkinDetailCard: View {
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
