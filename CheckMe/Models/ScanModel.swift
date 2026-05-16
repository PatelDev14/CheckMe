//
//  ScanModel.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Foundation
import SwiftData
import FoundationModels

// MARK: - Scanned Item

@Model
class ScanModel: Identifiable {
    var itemName: String
    var ingredients: [String]
    var dateSaved: Date = Date.now
    var category: String = HealthCategory.food.rawValue

    @Relationship(deleteRule: .cascade)
    var summary: GeneralSummaryModel?

    @Relationship(deleteRule: .cascade)
    var gutPrediction: SavedGutPrediction?

    init(itemName: String, ingredients: [String], category: HealthCategory = .food) {
        self.itemName = itemName
        self.ingredients = ingredients
        self.category = category.rawValue
    }

    var healthCategory: HealthCategory {
        HealthCategory(rawValue: category) ?? .food
    }
}

// MARK: - Persisted AI Summary

@Model
class GeneralSummaryModel {
    var overview: String
    var digestionProcess: String
    var complexity: String

    init(overview: String, digestionProcess: String, complexity: String) {
        self.overview = overview
        self.digestionProcess = digestionProcess
        self.complexity = complexity
    }
}

// MARK: - Persisted Prediction

@Model
class SavedGutPrediction {
    var prediction: String
    var triggers: [String]
    var tip: String
    var timestamp: Date

    init(from gutPrediction: GutPrediction) {
        self.prediction = gutPrediction.prediction
        self.triggers = gutPrediction.triggers
        self.tip = gutPrediction.tip
        self.timestamp = Date.now
    }
}

extension SavedGutPrediction {
    func toGutPrediction() -> GutPrediction {
        GutPrediction(prediction: prediction, triggers: triggers, tip: tip)
    }
}

// MARK: - Foundation Models Generable Types

@Generable
struct GeneralSummary {
    @Guide(description: "Provide a short, neutral overview (1–2 sentences) describing what it is generally like to consume or use a product made from the given ingredients.")
    var overview: String

    @Guide(description: "Describe, in general terms, how the ingredients are typically processed by the body.")
    var digestionProcess: String

    @Guide(description: "Describe the overall complexity of the ingredient list in terms of variety and formulation, using neutral language.")
    var complexity: String
}

@Generable
struct GutPrediction {
    @Guide(description: "Rate digestive comfort level using EXACTLY one of these three phrases: 'Gut Friendly' (minimal triggers), 'Moderate Risk' (1–2 mild triggers), or 'High Risk' (3+ serious triggers). Include this exact phrase followed by a brief reason in one sentence.")
    var prediction: String

    @Guide(description: "List 1–3 specific ingredients that may cause digestive discomfort for sensitive stomachs. If none, return an empty array.")
    var triggers: [String]

    @Guide(description: "One actionable tip for consuming this product safely. Keep it brief and practical.")
    var tip: String
}
