import Foundation
import Observation

// MARK: - User Profile Data

struct UserProfile: Codable {
    var foodRestrictions: [String]    = []
    var foodAllergies: [String]       = []
    var digestiveConditions: [String] = []
    var skinType: String              = ""
    var skinConditions: [String]      = []
    var healthGoals: [String]         = []
    var extraNotes: String            = ""

    var isEmpty: Bool {
        foodRestrictions.isEmpty &&
        foodAllergies.isEmpty &&
        digestiveConditions.isEmpty &&
        skinType.isEmpty &&
        skinConditions.isEmpty &&
        healthGoals.isEmpty &&
        extraNotes.isEmpty
    }

    // MARK: - Profile Completeness (5 trackable sections)

    static let totalSections = 5

    /// Names of sections the user has filled in at least partially.
    var completedSections: [String] {
        var s: [String] = []
        if !foodRestrictions.isEmpty                          { s.append("Dietary") }
        if !foodAllergies.isEmpty || !digestiveConditions.isEmpty { s.append("Gut Health") }
        if !skinType.isEmpty || !skinConditions.isEmpty       { s.append("Skin") }
        if !healthGoals.isEmpty                               { s.append("Goals") }
        if !extraNotes.isEmpty                                { s.append("Notes") }
        return s
    }

    var completenessScore: Int { completedSections.count }

    // MARK: - Attribution Tags (shown in result views)

    /// Compact tags shown as "Analysis used: IBS, Gluten-Free" in food scan results.
    var foodProfileTags: [String] {
        var tags: [String] = []
        tags += foodRestrictions
        tags += foodAllergies
        tags += digestiveConditions
        tags += healthGoals
        return tags
    }

    /// Compact tags shown in personal care scan results.
    var skinProfileTags: [String] {
        var tags: [String] = []
        if !skinType.isEmpty { tags.append(skinType) }
        tags += skinConditions
        // Include goals relevant to skin/inflammation
        tags += healthGoals.filter {
            let l = $0.lowercased()
            return l.contains("skin") || l.contains("inflam")
        }
        return tags
    }

    // MARK: - AI Prompt Context Builders

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
        if !healthGoals.isEmpty {
            parts.append("Health goals: \(healthGoals.joined(separator: ", ")).")
        }
        if !extraNotes.isEmpty {
            parts.append("Extra notes: \(extraNotes)")
        }
        return parts.isEmpty ? "" : "User profile — \(parts.joined(separator: " "))"
    }

    var skinPromptContext: String {
        var parts: [String] = []
        if !skinType.isEmpty {
            parts.append("Skin type: \(skinType).")
        }
        if !skinConditions.isEmpty {
            parts.append("Skin conditions: \(skinConditions.joined(separator: ", ")).")
        }
        if !healthGoals.isEmpty {
            parts.append("Health goals: \(healthGoals.joined(separator: ", ")).")
        }
        if !extraNotes.isEmpty {
            parts.append("Extra notes: \(extraNotes)")
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

    /// Creates a store pre-seeded with a given profile without persisting to UserDefaults.
    /// `didSet` is not called during `init`, so nothing is written to storage.
    /// Use this only for previews and example sheets.
    init(previewProfile: UserProfile) {
        profile = previewProfile
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
    static let healthGoals = [
        "Lose Weight", "Build Muscle", "Improve Gut Health",
        "Manage Allergies", "Reduce Inflammation", "Improve Skin Health",
        "Increase Energy", "Eat Cleaner"
    ]
}
