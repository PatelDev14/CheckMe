import SwiftUI

// Animated composition card showing per-serving macro breakdown.
// Main viz: full-width horizontal segmented bar that fills left-to-right.
// Legend: 2-column grid with actual gram weights and % shares.
// Allergens: amber disclosure strip when present.

struct ContainerFillView: View {
    let containerType: String           // "bottle" | "jar" | "bag" | "box"
    let layerNames: [String]
    let layerPercents: [String]
    var gramValues: [String: Double]    // layer name → actual grams
    var allergens: [String]             // e.g. ["Wheat", "Milk", "Soy"]

    @State private var barProgress: Double = 0   // drives the bar fill animation
    @State private var legendShown: Bool = false
    @State private var selectedNutrient: NutrientKnowledge?

    // Fixed colour palette — order matches layer priority from VM
    private static let palette: [Color] = [
        Color(red: 0.25, green: 0.55, blue: 0.95),   // blue   — Water
        Color(red: 0.95, green: 0.30, blue: 0.25),   // red    — Sugar
        Color(red: 0.95, green: 0.72, blue: 0.22),   // amber  — Net Carbs
        Color(red: 0.95, green: 0.55, blue: 0.10),   // orange — Fat
        Color(red: 0.20, green: 0.80, blue: 0.48),   // green  — Protein
        Color(red: 0.50, green: 0.85, blue: 0.65),   // teal   — Fiber
    ]

    private var layers: [(name: String, percent: Double, color: Color)] {
        zip(layerNames, layerPercents).enumerated().compactMap { i, pair in
            let (name, str) = pair
            guard let pct = Double(str), pct > 0 else { return nil }
            let color = i < Self.palette.count ? Self.palette[i] : .gray
            return (name: name, percent: pct, color: color)
        }
    }

    private var containerIcon: String {
        switch containerType {
        case "bottle": return "waterbottle.fill"
        case "jar":    return "cylinder.fill"
        case "bag":    return "bag.fill"
        default:       return "square.3.layers.3d"
        }
    }

    init(
        containerType: String,
        layerNames: [String],
        layerPercents: [String],
        gramValues: [String: Double] = [:],
        allergens: [String] = []
    ) {
        self.containerType = containerType
        self.layerNames    = layerNames
        self.layerPercents = layerPercents
        self.gramValues    = gramValues
        self.allergens     = allergens
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: containerIcon)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                Text("What's Inside")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text("per serving")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.bottom, 14)

            // ── Segmented bar ─────────────────────────────────────
            segmentedBar
                .padding(.bottom, 16)

            // ── Legend grid ───────────────────────────────────────
            legendGrid
                .opacity(legendShown ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.45), value: legendShown)

            // ── Allergen disclosure ───────────────────────────────
            if !allergens.isEmpty {
                allergenSection
                    .padding(.top, 14)
            }

            // ── Footnote ──────────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "info.circle").font(.system(size: 8))
                Text("Estimated from nutritional data  ·  Tap a nutrient to learn more")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.25))
            .padding(.top, 12)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        .onAppear { animateIn() }
        .sheet(item: $selectedNutrient) { NutrientInfoSheet(knowledge: $0) }
    }

    // MARK: - Segmented Bar

    private var segmentedBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 26)

                // Coloured segments
                HStack(spacing: 2) {
                    ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                        let w = max(2, geo.size.width * CGFloat(layer.percent) / 100.0)
                        LinearGradient(
                            colors: [layer.color.opacity(0.75), layer.color],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(width: w, height: 26)
                    }
                }
                .scaleEffect(x: barProgress, anchor: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Percentage labels inside bar (only if wide enough)
                HStack(spacing: 2) {
                    ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                        let w = geo.size.width * CGFloat(layer.percent) / 100.0 * barProgress
                        Group {
                            if w > 32 {
                                Text("\(Int(layer.percent))%")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .frame(width: max(2, geo.size.width * CGFloat(layer.percent) / 100.0), height: 26)
                    }
                }
            }
        }
        .frame(height: 26)
    }

    // MARK: - Legend Grid

    private var legendGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                legendCell(layer: layer)
            }
        }
    }

    private func legendCell(layer: (name: String, percent: Double, color: Color)) -> some View {
        let hasKnowledge = NutrientKnowledge.all[knowledgeKey(for: layer.name)] != nil
        return Button {
            if hasKnowledge, let k = NutrientKnowledge.all[knowledgeKey(for: layer.name)] {
                selectedNutrient = k
            }
        } label: {
            HStack(spacing: 8) {
                // Colour swatch
                RoundedRectangle(cornerRadius: 3)
                    .fill(layer.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: layer.color.opacity(0.4), radius: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(layer.name)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let g = gramValues[layer.name], g > 0 {
                            Text(formatGrams(g))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(layer.color)
                        }
                        Text("~\(Int(layer.percent))%")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                }

                Spacer(minLength: 0)

                if hasKnowledge {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.20))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(layer.color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(layer.color.opacity(0.18), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Allergen Section

    private var allergenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.98, green: 0.65, blue: 0.12))
                Text("Contains Allergens")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.85))
            }

            FlowLayout(spacing: 6) {
                ForEach(allergens, id: \.self) { allergen in
                    Text(allergen)
                        .font(.caption2).fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color(red: 0.98, green: 0.65, blue: 0.12).opacity(0.14))
                        )
                        .overlay(
                            Capsule().stroke(
                                Color(red: 0.98, green: 0.65, blue: 0.12).opacity(0.40),
                                lineWidth: 0.75
                            )
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.65, blue: 0.12).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.98, green: 0.65, blue: 0.12).opacity(0.18), lineWidth: 0.75)
        )
    }

    // MARK: - Helpers

    private func knowledgeKey(for name: String) -> String {
        switch name {
        case "Fat":       return "Fat"
        case "Sugar":     return "Sugar"
        case "Net Carbs": return "Starch"   // maps to the Starch knowledge entry
        case "Protein":   return "Protein"
        case "Fiber":     return "Fiber"
        case "Water":     return "Water"
        default:          return name
        }
    }

    private func formatGrams(_ g: Double) -> String {
        g == g.rounded() ? "\(Int(g))g" : String(format: "%.1fg", g)
    }

    // MARK: - Animation

    private func animateIn() {
        withAnimation(.spring(response: 0.80, dampingFraction: 0.72).delay(0.1)) {
            barProgress = 1.0
        }
        legendShown = true
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
