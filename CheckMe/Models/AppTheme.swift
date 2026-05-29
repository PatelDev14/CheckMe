import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case darkIndigoPurple  = "Indigo & Purple"
    case midnight          = "Midnight Blue"
    case crimson           = "Crimson & Rose"
    case darkGreenEmerald  = "Forest & Emerald"
    case obsidian          = "Obsidian & Violet"
    case slateTeal         = "Slate & Teal"

    var displayName: String { rawValue }

    var colors: ThemeColors {
        switch self {
        case .darkIndigoPurple:
            return ThemeColors(
                primary:       Color(red: 0.18, green: 0.08, blue: 0.38),
                secondary:     Color(red: 0.38, green: 0.08, blue: 0.58),
                accent:        Color(red: 0.6,  green: 0.3,  blue: 0.9),
                background:    Color(red: 0.07, green: 0.04, blue: 0.14),
                surface:       Color(red: 0.14, green: 0.09, blue: 0.24),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .midnight:
            return ThemeColors(
                primary:       Color(red: 0.04, green: 0.08, blue: 0.22),
                secondary:     Color(red: 0.04, green: 0.28, blue: 0.48),
                accent:        Color(red: 0.2,  green: 0.6,  blue: 0.9),
                background:    Color(red: 0.02, green: 0.04, blue: 0.12),
                surface:       Color(red: 0.06, green: 0.10, blue: 0.20),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .crimson:
            return ThemeColors(
                primary:       Color(red: 0.30, green: 0.04, blue: 0.08),
                secondary:     Color(red: 0.55, green: 0.08, blue: 0.22),
                accent:        Color(red: 0.9,  green: 0.35, blue: 0.5),
                background:    Color(red: 0.10, green: 0.02, blue: 0.04),
                surface:       Color(red: 0.22, green: 0.05, blue: 0.10),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .darkGreenEmerald:
            return ThemeColors(
                primary:       Color(red: 0.04, green: 0.18, blue: 0.10),
                secondary:     Color(red: 0.04, green: 0.36, blue: 0.22),
                accent:        Color(red: 0.15, green: 0.8,  blue: 0.5),
                background:    Color(red: 0.02, green: 0.08, blue: 0.05),
                surface:       Color(red: 0.05, green: 0.16, blue: 0.10),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .obsidian:
            return ThemeColors(
                primary:       Color(red: 0.08, green: 0.06, blue: 0.12),
                secondary:     Color(red: 0.28, green: 0.10, blue: 0.45),
                accent:        Color(red: 0.65, green: 0.35, blue: 1.0),
                background:    Color(red: 0.04, green: 0.03, blue: 0.07),
                surface:       Color(red: 0.10, green: 0.08, blue: 0.16),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .slateTeal:
            return ThemeColors(
                primary:       Color(red: 0.10, green: 0.14, blue: 0.18),
                secondary:     Color(red: 0.06, green: 0.34, blue: 0.38),
                accent:        Color(red: 0.2,  green: 0.75, blue: 0.75),
                background:    Color(red: 0.04, green: 0.06, blue: 0.09),
                surface:       Color(red: 0.11, green: 0.14, blue: 0.18),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        }
    }

    // Header/accent gradient used in scan result cards
    var gradient: LinearGradient {
        LinearGradient(
            colors: [colors.primary, colors.secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Main background gradient — top-to-bottom fade from the theme's secondary colour
    // (more saturated, richer) through primary down to the deep background.
    // Three stops create visible depth without going neon.
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                colors.secondary.opacity(0.55),
                colors.primary.opacity(0.80),
                colors.background,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Swatch used in the theme picker grid
    var swatchGradient: LinearGradient {
        LinearGradient(
            colors: [colors.primary, colors.secondary, colors.background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background Pattern

/// Selects the animated background pattern used per app section.
enum BackgroundPattern {
    /// Connected node network — ingredient molecule analysis (Nutrition / general).
    case molecular
    /// Circles of varying sizes rising slowly — gut cells / digestive bubbles (Food / Gut Health).
    case gutCells
    /// Pulsing honeycomb hexagons — skin cell structure (Personal Care).
    case hexSkin
}

// MARK: - Animated Background

struct AnimatedThemeBackground: View {
    let theme: AppTheme
    var pattern: BackgroundPattern = .molecular

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    switch pattern {
                    case .molecular: drawMolecular(ctx: ctx, size: size, t: t)
                    case .gutCells:  drawGutCells(ctx: ctx, size: size, t: t)
                    case .hexSkin:   drawHexSkin(ctx: ctx, size: size, t: t)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Molecular Network (Nutrition)
    // 38 nodes spread via Halton sequence; edges appear when nodes are close.

    private func drawMolecular(ctx: GraphicsContext, size: CGSize, t: Double) {
        let count = 38
        let positions = (0..<count).map { driftPos(i: $0, size: size, t: t,
                                                    speedX: 0.14, speedY: 0.11) }
        let threshold = min(size.width, size.height) * 0.30
        let accent    = theme.colors.accent

        for i in 0..<count {
            for j in (i + 1)..<count {
                let d = cgDist(positions[i], positions[j])
                guard d < threshold else { continue }
                let alpha = Double(1 - d / threshold) * 0.45
                var p = Path(); p.move(to: positions[i]); p.addLine(to: positions[j])
                ctx.stroke(p, with: .color(accent.opacity(alpha)), lineWidth: 0.8)
            }
        }
        for (i, pos) in positions.enumerated() {
            let hub    = i % 6 == 0
            let r      = CGFloat(hub ? 3.5 : 2.2)
            let alpha  = Double(hub ? 0.85 : 0.55)
            if hub {
                let gr = r * 2.8
                ctx.fill(Path(ellipseIn: CGRect(x: pos.x-gr, y: pos.y-gr,
                                                width: gr*2, height: gr*2)),
                         with: .color(accent.opacity(0.12)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-r, y: pos.y-r,
                                            width: r*2, height: r*2)),
                     with: .color(accent.opacity(alpha)))
        }
    }

    // MARK: - Gut Cells / Bubbles (Food / Gut Health)
    // Circles of varied size rise continuously from bottom to top, swaying slightly.
    // Larger ones carry a faint nucleus ring — like cells drifting through a digestive tract.

    private func drawGutCells(ctx: GraphicsContext, size: CGSize, t: Double) {
        let accent = theme.colors.accent
        let count  = 24

        for i in 0..<count {
            let fi = Double(i)

            // Each cell has a fixed X band and its own rise speed
            let baseX  = size.width  * halton(i + 1, base: 2)
            let speed  = 0.012 + 0.007 * halton(i + 1, base: 5)   // varied rise rates

            // Y rises from bottom to top, wrapping seamlessly
            // offset by fi/count so they're staggered at startup
            let rawY = size.height
                     - fmod(t * speed * size.height + fi / Double(count) * size.height,
                            size.height)

            // Gentle horizontal sway
            let sway = size.width * 0.025 * CGFloat(sin(t * 0.18 + fi * 1.9))
            let cx   = CGFloat(baseX) + sway
            let cy   = CGFloat(rawY)

            // Radius: mix of small bubbles and larger cells
            let radius = CGFloat(6 + 18 * halton(i + 1, base: 7))

            // Fade in near bottom, fade out near top
            let ny    = rawY / size.height          // 0 = top, 1 = bottom
            let fade  = min(ny * 5.0, (1.0 - ny) * 5.0, 1.0)
            let alpha = fade * (0.20 + 0.10 * sin(t * 0.3 + fi))

            // Outer membrane ring
            let outerRect = CGRect(x: cx - radius, y: cy - radius,
                                   width: radius * 2, height: radius * 2)
            ctx.stroke(Path(ellipseIn: outerRect),
                       with: .color(accent.opacity(alpha)), lineWidth: 1.1)

            // Subtle fill on every third cell
            if i % 3 == 0 {
                ctx.fill(Path(ellipseIn: outerRect),
                         with: .color(accent.opacity(alpha * 0.07)))
            }

            // Nucleus ring on larger cells
            if radius > 16 {
                let nr   = radius * 0.38
                let nRect = CGRect(x: cx - nr, y: cy - nr, width: nr * 2, height: nr * 2)
                ctx.stroke(Path(ellipseIn: nRect),
                           with: .color(accent.opacity(alpha * 0.45)), lineWidth: 0.7)
            }
        }
    }

    // MARK: - Hex Skin Cells (Personal Care)
    // A honeycomb grid covers the screen; a slow radial wave modulates each hex's opacity.

    private func drawHexSkin(ctx: GraphicsContext, size: CGSize, t: Double) {
        let accent = theme.colors.accent
        let R: CGFloat = 26                       // circumradius
        let colStep = R * 1.5
        let rowStep = R * CGFloat(3.0.squareRoot())
        let cols    = Int(size.width  / colStep) + 3
        let rows    = Int(size.height / rowStep) + 3

        for col in -1..<cols {
            for row in -1..<rows {
                let cx = CGFloat(col) * colStep - R * 0.5
                let cy = CGFloat(row) * rowStep + (col % 2 == 0 ? 0 : rowStep * 0.5) - rowStep

                let dx   = cx - size.width  * 0.5
                let dy   = cy - size.height * 0.5
                let wave = sin(t * 0.35 - sqrt(dx*dx + dy*dy) / 110.0)
                let alpha = Double((wave + 1) * 0.5) * 0.20 + 0.03

                var hex = Path()
                for k in 0..<6 {
                    let angle = CGFloat(k) * .pi / 3 + .pi / 6
                    let pt = CGPoint(x: cx + R * cos(angle), y: cy + R * sin(angle))
                    k == 0 ? hex.move(to: pt) : hex.addLine(to: pt)
                }
                hex.closeSubpath()
                ctx.stroke(hex, with: .color(accent.opacity(alpha)), lineWidth: 0.9)
            }
        }
    }

    // MARK: - Shared helpers

    /// Halton low-discrepancy base position + time-driven oscillation.
    private func driftPos(i: Int, size: CGSize, t: Double,
                          speedX: Double, speedY: Double) -> CGPoint {
        let baseX  = size.width  * halton(i + 1, base: 2)
        let baseY  = size.height * halton(i + 1, base: 3)
        let phase1 = Double(i) * 2.39996
        let phase2 = Double(i) * 1.61803
        let r      = min(size.width, size.height) * 0.065
        return CGPoint(
            x: baseX + r * sin(t * speedX + phase1),
            y: baseY + r * cos(t * speedY + phase2)
        )
    }

    private func halton(_ n: Int, base: Int) -> Double {
        var result = 0.0, f = 1.0 / Double(base), i = n
        while i > 0 { result += f * Double(i % base); i /= base; f /= Double(base) }
        return result
    }

    private func cgDist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

struct ThemeColors {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let text: Color
    let textSecondary: Color
}

// MARK: - Color Scheme Preference

enum AppColorScheme: String, CaseIterable, Codable {
    case system = "System"
    case dark   = "Always Dark"
    case light  = "Always Light"

    var resolved: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        }
    }
}

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    var selectedTheme: AppTheme {
        didSet { save() }
    }

    var colorSchemePreference: AppColorScheme {
        didSet { save() }
    }

    private let themeKey  = "selectedAppTheme"
    private let schemeKey = "selectedColorScheme"

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: "selectedAppTheme"),
           let theme = AppTheme(rawValue: rawValue) {
            selectedTheme = theme
        } else {
            selectedTheme = .darkIndigoPurple
        }

        if let rawValue = UserDefaults.standard.string(forKey: "selectedColorScheme"),
           let scheme = AppColorScheme(rawValue: rawValue) {
            colorSchemePreference = scheme
        } else {
            colorSchemePreference = .system
        }
    }

    private func save() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: themeKey)
        UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: schemeKey)
    }
}

// MARK: - Environment

struct ThemeKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager()
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
