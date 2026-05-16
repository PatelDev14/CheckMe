//
//  UserProfile.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Foundation
import Observation

// MARK: - User Profile Data

struct UserProfile: Codable {
    var foodRestrictions: [String] = []
    var foodAllergies: [String]    = []
    var digestiveConditions: [String] = []
    var skinType: String           = ""
    var skinConditions: [String]   = []
    var extraNotes: String         = ""

    var isEmpty: Bool {
        foodRestrictions.isEmpty &&
        foodAllergies.isEmpty &&
        digestiveConditions.isEmpty &&
        skinType.isEmpty &&
        skinConditions.isEmpty &&
        extraNotes.isEmpty
    }

    // MARK: - AI prompt context builders

    /// Injects user food context into an AI prompt string
    var foodPromptContext: String {
        var parts: [String] = []
        if !foodRestrictions.isEmpty {
            parts.append("Dietary restrictions: \(foodRestrictions.joined(separator: ", ")).")
        }
        if !foodAllergies.isEmpty {
            parts.append("Allergies: \(foodAllergies.joined(separator: ", ")).")
        }
        if !digestiveConditions.isEmpty {
            parts.append("Digestive conditions: \(digestiveConditions.joined(separator: ", ")).")
        }
        if !extraNotes.isEmpty {
            parts.append("Extra notes from user: \(extraNotes)")
        }
        return parts.isEmpty ? "" : "User profile — \(parts.joined(separator: " "))"
    }

    /// Injects user skin context into an AI prompt string
    var skinPromptContext: String {
        var parts: [String] = []
        if !skinType.isEmpty {
            parts.append("Skin type: \(skinType).")
        }
        if !skinConditions.isEmpty {
            parts.append("Skin conditions: \(skinConditions.joined(separator: ", ")).")
        }
        if !extraNotes.isEmpty {
            parts.append("Extra notes from user: \(extraNotes)")
        }
        return parts.isEmpty ? "" : "User profile — \(parts.joined(separator: " "))"
    }
}

// MARK: - Store (Observable, persisted to UserDefaults)

@Observable
final class UserProfileStore {
    private let key = "userProfile"

    var profile: UserProfile {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = UserProfile()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Static option lists

enum ProfileOptions {
    static let foodRestrictions = [
        "Gluten-Free", "Dairy-Free", "Vegan", "Vegetarian",
        "Keto", "Low-FODMAP", "Diabetic-Friendly", "Halal", "Kosher"
    ]
    static let foodAllergies = [
        "Peanuts", "Tree Nuts", "Milk", "Eggs",
        "Wheat", "Soy", "Fish", "Shellfish", "Sesame"
    ]
    static let digestiveConditions = [
        "IBS", "Crohn's Disease", "Ulcerative Colitis",
        "GERD / Acid Reflux", "Celiac Disease", "Lactose Intolerance"
    ]
    static let skinTypes = [
        "Normal", "Oily", "Dry", "Combination", "Sensitive"
    ]
    static let skinConditions = [
        "Acne-Prone", "Eczema", "Rosacea",
        "Psoriasis", "Hyperpigmentation", "Perioral Dermatitis"
    ]
}
