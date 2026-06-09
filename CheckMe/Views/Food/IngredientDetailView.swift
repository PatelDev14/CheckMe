import SwiftUI
import SwiftData

// Deep-dive view for a single ingredient.
// Uses Apple Intelligence (on-device) to generate a rich, visual analysis:
//   • Safety rating + origin badges so the user understands risk at a glance
//   • Processing-speed bar — visual metaphor for how fast the body handles it
//   • Key-facts chips — 3 scannable bullet points, no walls of text
//   • Staggered card animations — each section reveals itself sequentially

struct IngredientDetailView: View {
    let ingredientName: String
    let scan: ScanModel

    @Environment(\.modelContext)      private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self)   private var themeManager

    @State private var analysis: IngredientsModel?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var revealed = false          // drives stagger animations
    @State private var barProgress: CGFloat = 0  // drives processing-speed bar

    // MARK: - Status helpers

    private var isBlacklisted: Bool {
        let lower = ingredientName.lowercased()
        return profileStore.profile.blacklistedIngredients
            .contains { lower.contains($0.lowercased()) || $0.lowercased().contains(lower) }
    }

    private var isTrigger: Bool {
        guard !isBlacklisted else { return false }
        let triggers = scan.gutPrediction?.triggers ?? []
        let lower = ingredientName.lowercased()
        return triggers.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    private var isCaution: Bool {
        guard !isTrigger, !isBlacklisted else { return false }
        let cautions = scan.gutPrediction?.cautions ?? []
        let lower = ingredientName.lowercased()
        return cautions.contains { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }
    }

    private var flagColor: Color {
        isBlacklisted ? .orange : isTrigger ? .red : isCaution ? .yellow : .white
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
                        // Safety + Origin badges row
                        badgesRow(safety: a.safetyRating, origin: a.origin)
                            .staggerReveal(revealed, delay: 0.05)

                        // Processing-speed bar
                        processingSpeedCard(speed: a.processingSpeed)
                            .staggerReveal(revealed, delay: 0.12)

                        // What is it?
                        InfoCard(
                            icon: "info.circle.fill",
                            iconColor: .blue,
                            title: "What is it?",
                            text: a.explanation,
                            accentColor: originColor(a.origin)
                        )
                        .staggerReveal(revealed, delay: 0.20)

                        // Key facts chips
                        if !a.keyFacts.isEmpty {
                            keyFactsCard(facts: a.keyFacts)
                                .staggerReveal(revealed, delay: 0.28)
                        }

                        // How does your body process it?
                        InfoCard(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .green,
                            title: "How does your body process it?",
                            text: a.digestion,
                            accentColor: .green
                        )
                        .staggerReveal(revealed, delay: 0.36)

                        // How does it feel?
                        feelCard(text: a.digestiveFeel)
                            .staggerReveal(revealed, delay: 0.44)

                        // Flag warning
                        if isBlacklisted {
                            flaggedWarningCard(
                                color: .orange,
                                icon: "hand.raised.fill",
                                title: "Personally Blocked",
                                message: "You have added this ingredient to your personal blacklist. CheckMe will always highlight it across all scan results."
                            )
                            .staggerReveal(revealed, delay: 0.52)
                        } else if isTrigger {
                            flaggedWarningCard(
                                color: .red,
                                icon: "xmark.octagon.fill",
                                title: "Flagged as Avoid",
                                message: "CheckMe's gut analysis identified this as a significant concern based on your dietary profile."
                            )
                            .staggerReveal(revealed, delay: 0.52)
                        } else if isCaution {
                            flaggedWarningCard(
                                color: .yellow,
                                icon: "exclamationmark.triangle.fill",
                                title: "Flagged as Caution",
                                message: "CheckMe's gut analysis identified this as a mild concern worth monitoring."
                            )
                            .staggerReveal(revealed, delay: 0.52)
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
        HStack(alignment: .top, spacing: 10) {
            if isBlacklisted || isTrigger || isCaution {
                Image(systemName: isBlacklisted ? "hand.raised.fill" : isTrigger ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(flagColor)
                    .frame(width: 18)
            }
            Text(ingredientName)
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(isBlacklisted || isTrigger || isCaution ? flagColor : .white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(
            (isBlacklisted || isTrigger || isCaution) ? flagColor.opacity(0.12) : themeManager.selectedTheme.colors.surface
        ))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
            (isBlacklisted || isTrigger || isCaution) ? flagColor.opacity(0.4) : Color.white.opacity(0.1),
            lineWidth: 1
        ))
    }

    // MARK: - Badges row

    private func badgesRow(safety: String, origin: String) -> some View {
        HStack(spacing: 10) {
            // Safety badge
            HStack(spacing: 6) {
                Image(systemName: safetyIcon(safety))
                    .font(.caption2)
                Text(safety)
                    .font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(safetyColor(safety))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(safetyColor(safety).opacity(0.12)))
            .overlay(Capsule().stroke(safetyColor(safety).opacity(0.3), lineWidth: 1))

            // Origin badge
            HStack(spacing: 6) {
                Image(systemName: originIcon(origin))
                    .font(.caption2)
                Text(origin)
                    .font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(originColor(origin))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(originColor(origin).opacity(0.12)))
            .overlay(Capsule().stroke(originColor(origin).opacity(0.3), lineWidth: 1))

            Spacer()
        }
    }

    // MARK: - Processing Speed Bar

    private func processingSpeedCard(speed: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                Text("Digestive Speed")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text(speed)
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(speedColor(speed))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(speedColor(speed).opacity(0.15)))
            }

            // Animated track with % marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    // Filled bar
                    Capsule()
                        .fill(speedGradient(speed))
                        .frame(width: geo.size.width * barProgress, height: 8)
                        .animation(.easeInOut(duration: 0.9).delay(0.3), value: barProgress)
                    // Dot marker at tip
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .offset(x: geo.size.width * barProgress - 5, y: -1)
                        .animation(.easeInOut(duration: 0.9).delay(0.3), value: barProgress)
                }
            }
            .frame(height: 8)

            // Labels under the bar
            HStack {
                Text("Fast").font(.caption2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Moderate").font(.caption2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Slow").font(.caption2).foregroundStyle(.white.opacity(0.4))
            }

            // Digestive effort row
            HStack(spacing: 6) {
                Image(systemName: speedEffortIcon(speed))
                    .font(.caption2)
                    .foregroundStyle(speedColor(speed))
                Text(speedEffortLabel(speed))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(speedEffortPercent(speed))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(speedColor(speed))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.07), lineWidth: 1))
        .onAppear {
            barProgress = speedProgress(speed)
        }
    }

    // MARK: - Key Facts

    private func keyFactsCard(facts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
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

    // MARK: - Feel Card

    private func feelCard(text: String) -> some View {
        let (icon, color) = feelMeta(text)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text("How does it feel?")
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
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(color)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
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

    // MARK: - Product Context

    private var productContextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "fork.knife.circle")
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

    // MARK: - Data loading

    private func loadAnalysis() async {
        guard analysis == nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            let vm = IngredientsViewModel(modelContext: modelContext, profileStore: profileStore)
            analysis = try await vm.analyzeIngredient(ingredientName, in: scan)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                revealed = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Visual helpers

    private func safetyColor(_ rating: String) -> Color {
        switch rating {
        case "Generally Safe": return .green
        case "Monitor":        return .yellow
        case "Use Caution":    return .orange
        case "Avoid":          return .red
        default:               return .green
        }
    }

    private func safetyIcon(_ rating: String) -> String {
        switch rating {
        case "Generally Safe": return "checkmark.shield.fill"
        case "Monitor":        return "eye.fill"
        case "Use Caution":    return "exclamationmark.triangle.fill"
        case "Avoid":          return "xmark.shield.fill"
        default:               return "checkmark.shield.fill"
        }
    }

    private func originColor(_ origin: String) -> Color {
        switch origin {
        case "Natural":        return .green
        case "Semi-Synthetic": return .yellow
        case "Synthetic":      return .orange
        default:               return .green
        }
    }

    private func originIcon(_ origin: String) -> String {
        switch origin {
        case "Natural":        return "leaf.fill"
        case "Semi-Synthetic": return "arrow.triangle.2.circlepath"
        case "Synthetic":      return "flask.fill"
        default:               return "leaf.fill"
        }
    }

    private func speedColor(_ speed: String) -> Color {
        switch speed {
        case "Fast":     return .green
        case "Moderate": return .yellow
        case "Slow":     return .orange
        default:         return .yellow
        }
    }

    private func speedGradient(_ speed: String) -> LinearGradient {
        let color = speedColor(speed)
        return LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing)
    }

    private func speedProgress(_ speed: String) -> CGFloat {
        switch speed {
        case "Fast":     return 0.30
        case "Moderate": return 0.65
        case "Slow":     return 1.00
        default:         return 0.65
        }
    }

    private func speedEffortIcon(_ speed: String) -> String {
        switch speed {
        case "Fast":     return "hare.fill"
        case "Moderate": return "figure.walk"
        case "Slow":     return "tortoise.fill"
        default:         return "figure.walk"
        }
    }

    private func speedEffortLabel(_ speed: String) -> String {
        switch speed {
        case "Fast":     return "Low effort — digested within 1–2 hours"
        case "Moderate": return "Moderate effort — takes 2–4 hours"
        case "Slow":     return "High effort — can take 5+ hours to break down"
        default:         return "Normal digestion time"
        }
    }

    private func speedEffortPercent(_ speed: String) -> String {
        switch speed {
        case "Fast":     return "~30% load"
        case "Moderate": return "~65% load"
        case "Slow":     return "~95% load"
        default:         return "~65% load"
        }
    }

    /// Maps digestive-feel text to a descriptive SF Symbol + colour without asking the AI for icon names.
    private func feelMeta(_ text: String) -> (symbol: String, color: Color) {
        let lower = text.lowercased()
        if lower.contains("gentle") || lower.contains("smooth") || lower.contains("well-tolerat") || lower.contains("easy") {
            return ("checkmark.circle.fill", .green)
        }
        if lower.contains("energy") || lower.contains("boost") || lower.contains("stimulat") || lower.contains("quick") {
            return ("bolt.fill", .yellow)
        }
        if lower.contains("bloat") || lower.contains("gas") || lower.contains("discomfort") || lower.contains("upset") {
            return ("exclamationmark.bubble.fill", .orange)
        }
        if lower.contains("heavy") || lower.contains("slow") || lower.contains("sluggish") {
            return ("tortoise.fill", .orange)
        }
        if lower.contains("irritat") || lower.contains("avoid") || lower.contains("sensitiv") {
            return ("xmark.circle.fill", .red)
        }
        return ("figure.walk", themeManager.selectedTheme.colors.accent)
    }
}

// MARK: - Info Card (reusable)

struct InfoCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let icon: String
    let iconColor: Color
    let title: String
    let text: String
    var accentColor: Color = .clear

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
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
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor == .clear ? Color.white.opacity(0.07) : accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Stagger animation helper

private extension View {
    func staggerReveal(_ revealed: Bool, delay: Double) -> some View {
        self
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 6)
            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay), value: revealed)
    }
}
