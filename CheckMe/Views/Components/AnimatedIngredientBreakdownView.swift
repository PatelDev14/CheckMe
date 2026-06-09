import SwiftUI

// Animated categorized breakdown of a scan's ingredient list.
// Categories spring in one by one on first appearance. Tapping a card
// expands it to show ingredient chips; tapping a chip navigates to detail.

struct AnimatedIngredientBreakdownView: View {
    let scan: ScanModel
    let triggers: [String]
    let cautions: [String]
    var blacklisted: [String] = []

    @Environment(ThemeManager.self) private var themeManager

    @State private var groups: [IngredientGroup] = []
    @State private var visibleCount: Int = 0      // how many category cards have animated in
    @State private var expandedIDs: Set<String> = []
    @State private var hasAnimated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryStrip

            LazyVStack(spacing: 10) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index < visibleCount {
                        CategoryCard(
                            group: group,
                            scan: scan,
                            triggers: triggers,
                            cautions: cautions,
                            blacklisted: blacklisted,
                            isExpanded: expandedIDs.contains(group.id),
                            onToggle: { toggle(group.id) }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.85, anchor: .top)
                                    .combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
            }

            if visibleCount < groups.count {
                // Show a subtle skeleton while the remaining cards animate in
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.selectedTheme.colors.surface.opacity(0.4))
                    .frame(height: 56)
                    .overlay(
                        ProgressView()
                            .tint(.white.opacity(0.3))
                    )
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            groups = IngredientClassifier.categorize(scan.ingredients)
            animateIn()
        }
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groups) { group in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            toggle(group.id)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: group.category.icon)
                                .font(.caption2)
                            Text("\(group.items.count)")
                                .font(.caption2).fontWeight(.bold)
                        }
                        .foregroundStyle(group.category.signalColor)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(
                            Capsule().fill(group.category.signalColor.opacity(
                                expandedIDs.contains(group.id) ? 0.25 : 0.10
                            ))
                        )
                        .overlay(
                            Capsule().stroke(
                                group.category.signalColor.opacity(
                                    expandedIDs.contains(group.id) ? 0.6 : 0.2
                                ),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Animation

    private func animateIn() {
        for index in groups.indices {
            let delay = Double(index) * 0.11
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
                    visibleCount = index + 1
                }
            }
        }
    }

    private func toggle(_ id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
            } else {
                expandedIDs.insert(id)
            }
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let group: IngredientGroup
    let scan: ScanModel
    let triggers: [String]
    let cautions: [String]
    var blacklisted: [String] = []
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    private var flaggedCount: Int {
        group.items.filter { item in
            let lower = item.lowercased()
            let inBlacklist = blacklisted.contains { lower.contains($0.lowercased()) || $0.lowercased().contains(lower) }
            let inTriggers  = triggers.contains  { t in let tl = t.lowercased(); return tl.contains(lower) || lower.contains(tl) }
            let inCautions  = cautions.contains  { c in let cl = c.lowercased(); return cl.contains(lower) || lower.contains(cl) }
            return inBlacklist || inTriggers || inCautions
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (always visible, tappable) ──────────────────
            HStack(spacing: 12) {
                // Category icon circle
                ZStack {
                    Circle()
                        .fill(group.category.signalColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: group.category.icon)
                        .font(.subheadline)
                        .foregroundStyle(group.category.signalColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.category.rawValue)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text("\(group.items.count) ingredient\(group.items.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                        signalBadge
                    }
                }

                Spacer()

                // Flagged count badge (triggers + cautions + blacklisted)
                if flaggedCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark")
                            .font(.caption2).fontWeight(.bold)
                        Text("\(flaggedCount)")
                            .font(.caption2).fontWeight(.bold)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.red.opacity(0.15)))
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            // ── Expanded ingredient chips ───────────────────────────
            if isExpanded {
                Divider()
                    .overlay(group.category.signalColor.opacity(0.2))

                FlowLayout(spacing: 6) {
                    ForEach(group.items, id: \.self) { item in
                        NavigationLink(
                            destination: IngredientDetailView(ingredientName: item, scan: scan)
                        ) {
                            IngredientChip(
                                name: item,
                                triggers: triggers,
                                cautions: cautions,
                                blacklisted: blacklisted,
                                categoryColor: group.category.signalColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeManager.selectedTheme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(group.category.signalColor.opacity(isExpanded ? 0.4 : 0.18), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isExpanded)
    }

    private var signalBadge: some View {
        Text(group.category.signalBadge)
            .font(.caption2).fontWeight(.medium)
            .foregroundStyle(group.category.signalColor)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(group.category.signalColor.opacity(0.12)))
    }
}

// MARK: - Ingredient Chip

private struct IngredientChip: View {
    let name: String
    let triggers: [String]
    let cautions: [String]
    var blacklisted: [String] = []
    let categoryColor: Color

    private enum ChipStatus { case blacklisted, trigger, caution, neutral }

    private var status: ChipStatus {
        let lower = name.lowercased()
        if blacklisted.contains(where: { lower.contains($0.lowercased()) || $0.lowercased().contains(lower) }) {
            return .blacklisted
        }
        if triggers.contains(where: { lower.contains($0.lowercased()) || $0.lowercased().contains(lower) }) {
            return .trigger
        }
        if cautions.contains(where: { lower.contains($0.lowercased()) || $0.lowercased().contains(lower) }) {
            return .caution
        }
        return .neutral
    }

    private var chipColor: Color {
        switch status {
        case .blacklisted: return .orange
        case .trigger:     return .red
        case .caution:     return Color(red: 0.95, green: 0.80, blue: 0.15)
        case .neutral:     return categoryColor
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case .blacklisted:
                Image(systemName: "hand.raised.fill")
                    .font(.caption2).foregroundStyle(chipColor)
            case .trigger:
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2).foregroundStyle(chipColor)
            case .caution:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2).foregroundStyle(chipColor)
            case .neutral:
                EmptyView()
            }
            Text(name)
                .font(.caption2).fontWeight(.medium)
                .foregroundStyle(chipColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(chipColor.opacity(0.12)))
        .overlay(Capsule().stroke(chipColor.opacity(0.30), lineWidth: 1))
    }
}
