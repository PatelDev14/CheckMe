//
//  Item.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Foundation

// Note: rename this file to HealthCategory.swift in Xcode.

enum HealthCategory: String, CaseIterable, Codable, Identifiable {
    case food      = "Food"
    case skin      = "Skin"
    case nutrition = "Nutrition"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .food:      return "fork.knife"
        case .skin:      return "sparkles"
        case .nutrition: return "chart.pie.fill"
        }
    }

    var scanPromptLabel: String {
        switch self {
        case .food:      return "food label"
        case .skin:      return "skincare label"
        case .nutrition: return "nutrition facts panel"
        }
    }
}
