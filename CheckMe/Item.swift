//
//  Item.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Foundation

// Note: rename this file to HealthCategory.swift in Xcode.

enum HealthCategory: String, CaseIterable, Codable, Identifiable {
    case food = "Food"
    case skin = "Skin"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .skin: "sparkles"
        }
    }

    var scanPromptLabel: String {
        switch self {
        case .food: "food label"
        case .skin: "skincare label"
        }
    }
}
