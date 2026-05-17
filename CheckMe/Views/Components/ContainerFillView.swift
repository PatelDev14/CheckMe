import SwiftUI

// Animated layered container showing estimated product composition.
// Each layer fills from the bottom up with a staggered spring animation.
// Container proportions adapt to product type via shape sizing and corner radius.

struct ContainerFillView: View {
    let containerType: String   // "bottle" | "jar" | "bag" | "box"
    let layerNames: [String]
    let layerPercents: [String]

    @State private var fillProgress: [Double]   // 0 → 1 per layer

    private static let palette: [Color] = [
        Color(red: 0.25, green: 0.55, blue: 0.95),   // blue   (water)
        Color(red: 0.95, green: 0.35, blue: 0.25),   // red    (sugar)
        Color(red: 0.95, green: 0.75, blue: 0.20),   // yellow (fat/oil)
        Color(red: 0.20, green: 0.78, blue: 0.50),   // green  (protein/fiber)
        Color(red: 0.78, green: 0.52, blue: 0.30),   // brown  (starch/cocoa)
        Color(red: 0.65, green: 0.45, blue: 0.90),   // purple (additives/other)
    ]

    private var layers: [(name: String, percent: Double, color: Color)] {
        zip(layerNames, layerPercents).enumerated().compactMap { i, pair in
            let (name, str) = pair
            guard let pct = Double(str), pct > 0 else { return nil }
            let color = i < Self.palette.count ? Self.palette[i] : Color.gray
            return (name: name, percent: pct, color: color)
        }
    }

    // MARK: - Container geometry

    private var containerWidth: CGFloat {
        switch containerType {
        case "bottle": return 72
        case "jar":    return 110
        case "bag":    return 96
        default:       return 96
        }
    }

    private var containerHeight: CGFloat {
        switch containerType {
        case "bottle": return 200
        case "jar":    return 130
        default:       return 160
        }
    }

    private var cornerRadius: CGFloat {
        switch containerType {
        case "bottle": return 22
        case "jar":    return 12
        default:       return 14
        }
    }

    private var headerIcon: String {
        switch containerType {
        case "bottle": return "waterbottle.fill"
        case "jar":    return "cylinder.fill"
        case "bag":    return "bag.fill"
        default:       return "square.3.layers.3d"
        }
    }

    init(containerType: String, layerNames: [String], layerPercents: [String]) {
        self.containerType = containerType
        self.layerNames    = layerNames
        self.layerPercents = layerPercents
        _fillProgress = State(initialValue: Array(repeating: 0, count: layerNames.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Product Composition", systemImage: headerIcon)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 20) {
                // ── Container ──────────────────────────────────────
                ZStack(alignment: .bottom) {
                    layersStack(width: containerWidth, height: containerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: containerWidth, height: containerHeight)
                }
                .frame(width: containerWidth, height: containerHeight)

                // ── Legend ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(layers.enumerated()), id: \.offset) { i, layer in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(layer.color)
                                .frame(width: 12, height: 12)
                            Text(layer.name)
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("~\(Int(layer.percent))%")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(layer.color.opacity(0.9))
                        }
                        .opacity(fillProgress[safe: i] ?? 0)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 8))
                Text("* Proportions are estimated from nutritional data")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.28))
            .padding(.top, 12)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        .onAppear { animateLayers() }
    }

    // MARK: - Layer Stack

    private func layersStack(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(layers.enumerated()), id: \.offset) { i, layer in
                let targetH = height * CGFloat(layer.percent) / 100.0
                let offsetY  = cumulativeHeight(below: i, total: height)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [layer.color.opacity(0.65), layer.color.opacity(0.90)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: targetH * CGFloat(fillProgress[safe: i] ?? 0))
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .offset(y: -offsetY)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
    }

    private func cumulativeHeight(below index: Int, total: CGFloat) -> CGFloat {
        layers.prefix(index).reduce(0) { $0 + total * CGFloat($1.percent) / 100 }
    }

    // MARK: - Animation

    private func animateLayers() {
        for i in layers.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.70)) {
                    if i < fillProgress.count { fillProgress[i] = 1.0 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25 + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if i < fillProgress.count { fillProgress[i] = 1.0 }
                }
            }
        }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
