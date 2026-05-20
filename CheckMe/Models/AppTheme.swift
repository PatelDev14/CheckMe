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
