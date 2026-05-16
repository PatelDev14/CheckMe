//
//  AppTheme.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

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
                background:    Color(red: 0.10, green: 0.06, blue: 0.18),
                surface:       Color(red: 0.14, green: 0.09, blue: 0.24),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .midnight:
            return ThemeColors(
                primary:       Color(red: 0.04, green: 0.08, blue: 0.22),
                secondary:     Color(red: 0.04, green: 0.28, blue: 0.48),
                accent:        Color(red: 0.2,  green: 0.6,  blue: 0.9),
                background:    Color(red: 0.03, green: 0.05, blue: 0.14),
                surface:       Color(red: 0.06, green: 0.10, blue: 0.20),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .crimson:
            return ThemeColors(
                primary:       Color(red: 0.30, green: 0.04, blue: 0.08),
                secondary:     Color(red: 0.55, green: 0.08, blue: 0.22),
                accent:        Color(red: 0.9,  green: 0.35, blue: 0.5),
                background:    Color(red: 0.16, green: 0.03, blue: 0.06),
                surface:       Color(red: 0.22, green: 0.05, blue: 0.10),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .darkGreenEmerald:
            return ThemeColors(
                primary:       Color(red: 0.04, green: 0.18, blue: 0.10),
                secondary:     Color(red: 0.04, green: 0.36, blue: 0.22),
                accent:        Color(red: 0.15, green: 0.8,  blue: 0.5),
                background:    Color(red: 0.03, green: 0.11, blue: 0.07),
                surface:       Color(red: 0.05, green: 0.16, blue: 0.10),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .obsidian:
            return ThemeColors(
                primary:       Color(red: 0.08, green: 0.06, blue: 0.12),
                secondary:     Color(red: 0.28, green: 0.10, blue: 0.45),
                accent:        Color(red: 0.65, green: 0.35, blue: 1.0),
                background:    Color(red: 0.05, green: 0.04, blue: 0.08),
                surface:       Color(red: 0.10, green: 0.08, blue: 0.16),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        case .slateTeal:
            return ThemeColors(
                primary:       Color(red: 0.10, green: 0.14, blue: 0.18),
                secondary:     Color(red: 0.06, green: 0.34, blue: 0.38),
                accent:        Color(red: 0.2,  green: 0.75, blue: 0.75),
                background:    Color(red: 0.07, green: 0.09, blue: 0.12),
                surface:       Color(red: 0.11, green: 0.14, blue: 0.18),
                text:          .white,
                textSecondary: Color.white.opacity(0.7)
            )
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [colors.primary, colors.secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Small swatch for Settings preview
    var swatchView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(gradient)
            .frame(width: 48, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
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

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    var selectedTheme: AppTheme {
        didSet { save() }
    }

    private let key = "selectedAppTheme"

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: key),
           let theme = AppTheme(rawValue: rawValue) {
            selectedTheme = theme
        } else {
            selectedTheme = .darkIndigoPurple
        }
    }

    private func save() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: key)
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
