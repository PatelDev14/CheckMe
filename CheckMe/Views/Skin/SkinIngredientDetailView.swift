import SwiftUI
import SwiftData

// Deep-dive view for a single personal care / INCI ingredient.
// Mirrors the food IngredientDetailView visual language but uses skin-specific
// fields: penetration depth instead of processing speed, skinEffect instead of digestion.

struct SkinIngredientDetailView: View {
    let ingredientName: String
    let scan: ScanModel

    @Environment(\.modelContext)      private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self)   private var themeManager

    @State private var analysis: SkinIngredientModel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var revealed = false
    @State private var depthProgress: CGFloat = 0

    // MARK: - Status helpers

    private var isBlacklisted: Bool {
        let lower = ingredientName.lowercased()
        return profileStore.profile.blacklistedIngredients
            .contains { lower.contains($0.lowercased()) || $0.lowercased().contains(lower) }
    }

    private var isIrritant: Bool {
        guard !isBlacklisted else { return false }
        let irritants = scan.skinPrediction?.irritants ?? []
        let lower = ingredientName.lowercased()
        return irritants.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    private var isCaution: Bool {
        guard !isIrritant, !isBlacklisted else { return false }
        let cautions = scan.skinPrediction?.cautions ?? []
        let lower = ingredientName.lowercased()
        return cautions.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    private var flagColor: Color {
        isBlacklisted ? .orange : isIrritant ? .red : isCaution ? .yellow : .white
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            themeManager.selectedTheme.colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    ingredientHeader

                    if isLoading {
                        loadingCard
                    } else if let a = analysis {
                        badgesRow(safety: a.safetyRating, origin: a.origin)
                            .staggerReveal(revealed, delay: 0.05)

                        penetrationDepthCard(depth: a.penetrationDepth)
                            .staggerReveal(revealed, delay: 0.12)

                        InfoCard(
                            icon: "info.circle.fill",
                            iconColor: .purple,
                            title: "What is it?",
                            text: a.explanation,
                            accentColor: originColor(a.origin)
                        )
                        .staggerReveal(revealed, delay: 0.20)

                        if !a.keyFacts.isEmpty {
                            keyFactsCard(facts: a.keyFacts)
                                .staggerReveal(revealed, delay: 0.28)
                        }

                        InfoCard(
                            icon: "sparkles",
                            iconColor: .pink,
                            title: "How does your skin react?",
                            text: a.skinEffect,
                            accentColor: .pink
                        )
                        .staggerReveal(revealed, delay: 0.36)

                        suitabilityCard(text: a.suitability)
                            .staggerReveal(revealed, delay: 0.44)

                        flaggedWarningSection
                            .staggerReveal(revealed, delay: 0.52)
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

    // MARK: - Flagged warning (conditional)

    @ViewBuilder
    private var flaggedWarningSection: some View {
        if isBlacklisted {
            flaggedWarningCard(
                color: .orange,
                icon: "hand.raised.fill",
                title: "Personally Blocked",
                message: "You have added this ingredient to your personal blacklist. CheckMe will always highlight it across all scan results."
            )
        } else if isIrritant {
            flaggedWarningCard(
                color: .red,
                icon: "xmark.octagon.fill",
                title: "Flagged as Irritant",
                message: "CheckMe's skin analysis identified this as a significant concern for your skin profile. Consider avoiding this product or patch testing first."
            )
        } else if isCaution {
            flaggedWarningCard(
                color: .yellow,
                icon: "exclamationmark.triangle.fill",
                title: "Flagged as Caution",
                message: "CheckMe's skin analysis identified this as a mild concern. Monitor for reactions."
            )
        }
    }

    // MARK: - Header

    private var ingredientHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            if isBlacklisted || isIrritant || isCaution {
                Image(systemName: isBlacklisted ? "hand.raised.fill" : isIrritant ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(flagColor)
                    .frame(width: 18)
            }
            Text(ingredientName)
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(isBlacklisted || isIrritant || isCaution ? flagColor : .white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(
            (isBlacklisted || isIrritant || isCaution) ? flagColor.opacity(0.12) : themeManager.selectedTheme.colors.surface
        ))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
            (isBlacklisted || isIrritant || isCaution) ? flagColor.opacity(0.4) : Color.white.opacity(0.1),
            lineWidth: 1
        ))
    }

    // MARK: - Badges row

    private func badgesRow(safety: String, origin: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: safetyIcon(safety)).font(.caption2)
                Text(safety).font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(safetyColor(safety))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(safetyColor(safety).opacity(0.12)))
            .overlay(Capsule().stroke(safetyColor(safety).opacity(0.3), lineWidth: 1))

            HStack(spacing: 6) {
                Image(systemName: originIcon(origin)).font(.caption2)
                Text(origin).font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(originColor(origin))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(originColor(origin).opacity(0.12)))
            .overlay(Capsule().stroke(originColor(origin).opacity(0.3), lineWidth: 1))

            Spacer()
        }
    }

    // MARK: - Penetration Depth Bar

    private func penetrationDepthCard(depth: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                Text("How deep does it go?")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text(depthFriendlyLabel(depth))
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(depthColor(depth))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(depthColor(depth).opacity(0.15)))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    // Filled bar
                    Capsule()
                        .fill(depthGradient(depth))
                        .frame(width: geo.size.width * depthProgress, height: 8)
                        .animation(.easeInOut(duration: 0.9).delay(0.3), value: depthProgress)
                    // Dot marker at tip
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .offset(x: geo.size.width * depthProgress - 5, y: -1)
                        .animation(.easeInOut(duration: 0.9).delay(0.3), value: depthProgress)
                }
            }
            .frame(height: 8)

            // Friendly scale labels
            HStack {
                Text("On skin").font(.caption2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Outer layers").font(.caption2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Deep layers").font(.caption2).foregroundStyle(.white.opacity(0.4))
            }

            // Plain-English explanation
            HStack(spacing: 6) {
                Image(systemName: depthIcon(depth))
                    .font(.caption2)
                    .foregroundStyle(depthColor(depth))
                Text(depthFriendlyDesc(depth))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.07), lineWidth: 1))
        .onAppear { depthProgress = depthProgressValue(depth) }
    }

    // MARK: - Key Facts

    private func keyFactsCard(facts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text("Quick Facts")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            FlowLayout(spacing: 8) {
                ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                    factChip(number: index + 1, text: fact)
                        .scaleEffect(revealed ? 1 : 0.85)
                        .opacity(revealed ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.28 + Double(index) * 0.07), value: revealed)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private func factChip(number: Int, text: String) -> some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(.black)
                .frame(width: 16, height: 16)
                .background(Circle().fill(themeManager.selectedTheme.colors.accent))
            Text(text)
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Suitability Card

    private func suitabilityCard(text: String) -> some View {
        let (icon, color) = suitabilityMeta(text)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color)
                Text("Is it right for your skin?")
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Flag Warning

    private func flaggedWarningCard(color: Color, icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(color)
                Text(message)
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView().tint(themeManager.selectedTheme.colors.accent).scaleEffect(1.3)
            Text("Analysing with Apple Intelligence…")
                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Text("This result will be cached for instant access next time.")
                .font(.caption).foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundStyle(.orange)
            Text("Could not load analysis").font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
            Text(message).font(.caption).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            Button("Try Again") { Task { await loadAnalysis() } }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(themeManager.selectedTheme.colors.accent)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    private var productContextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(.white.opacity(0.4))
            Text("From: \(scan.itemName)").font(.caption).foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(scan.dateSaved.shortDisplay).font(.caption).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.selectedTheme.colors.surface.opacity(0.5)))
    }

    // MARK: - Data loading

    private func loadAnalysis() async {
        guard analysis == nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            let vm = SkinViewModel(modelContext: modelContext, profileStore: profileStore)
            analysis = try await vm.analyzeSkinIngredient(ingredientName, in: scan)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                revealed = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Visual helpers

    private func safetyColor(_ r: String) -> Color {
        switch r { case "Generally Safe": .green; case "Monitor": .yellow; case "Use Caution": .orange; default: .red }
    }
    private func safetyIcon(_ r: String) -> String {
        switch r { case "Generally Safe": "checkmark.shield.fill"; case "Monitor": "eye.fill"; case "Use Caution": "exclamationmark.triangle.fill"; default: "xmark.shield.fill" }
    }
    private func originColor(_ o: String) -> Color {
        switch o { case "Natural": .green; case "Semi-Synthetic": .yellow; default: .orange }
    }
    private func originIcon(_ o: String) -> String {
        switch o { case "Natural": "leaf.fill"; case "Semi-Synthetic": "arrow.triangle.2.circlepath"; default: "flask.fill" }
    }
    private func depthColor(_ d: String) -> Color {
        switch d { case "Surface": .green; case "Epidermal": .yellow; default: .purple }
    }
    private func depthGradient(_ d: String) -> LinearGradient {
        let c = depthColor(d)
        return LinearGradient(colors: [c.opacity(0.6), c], startPoint: .leading, endPoint: .trailing)
    }
    private func depthProgressValue(_ d: String) -> CGFloat {
        switch d { case "Surface": 0.25; case "Epidermal": 0.62; default: 1.0 }
    }
    private func depthFriendlyLabel(_ d: String) -> String {
        switch d {
        case "Surface":   return "Stays on skin"
        case "Epidermal": return "Into outer layers"
        case "Dermal":    return "Deep into skin"
        default:          return d
        }
    }
    private func depthFriendlyDesc(_ d: String) -> String {
        switch d {
        case "Surface":   return "Stays on top — forms a protective layer without being absorbed into skin."
        case "Epidermal": return "Absorbed into the upper skin layers — where most visible effects (hydration, brightness) happen."
        case "Dermal":    return "Reaches the deep layer — where collagen, elastin, and long-term skin changes occur."
        default:          return ""
        }
    }
    private func depthIcon(_ d: String) -> String {
        switch d {
        case "Surface":   return "rectangle.and.hand.point.up.left.fill"
        case "Epidermal": return "arrow.down.circle.fill"
        case "Dermal":    return "arrow.down.to.line.circle.fill"
        default:          return "arrow.down.circle"
        }
    }
    private func suitabilityMeta(_ text: String) -> (String, Color) {
        let lower = text.lowercased()
        if lower.contains("suitable") || lower.contains("well-suited") || lower.contains("beneficial") { return ("person.fill.checkmark", .green) }
        if lower.contains("caution") || lower.contains("patch test") || lower.contains("sensitive") { return ("exclamationmark.triangle.fill", .yellow) }
        if lower.contains("avoid") || lower.contains("not suitable") || lower.contains("irritat") { return ("person.fill.xmark", .red) }
        return ("person.fill.questionmark", .white.opacity(0.7))
    }
}

// MARK: - Stagger animation helper (mirrors food view)

private extension View {
    func staggerReveal(_ revealed: Bool, delay: Double) -> some View {
        self
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 6)
            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay), value: revealed)
    }
}
