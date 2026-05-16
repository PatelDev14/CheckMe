//
//  FoundationModelsManager.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Foundation
import FoundationModels

@Observable
class FoundationModelsManager {
    var notAvailableReason = "Checking for model availability."

    var isModelAvailable: Bool {
        notAvailableReason.isEmpty
    }

    init() {
        checkIsAvailable()
    }

    func checkIsAvailable() {
        switch SystemLanguageModel.default.availability {
        case .available:
            notAvailableReason = ""
        case .unavailable(.appleIntelligenceNotEnabled):
            notAvailableReason = "Enable Apple Intelligence in Settings."
        case .unavailable(.deviceNotEligible):
            notAvailableReason = "Apple Intelligence is not available on this device."
        case .unavailable(.modelNotReady):
            notAvailableReason = "Apple Intelligence is downloading or temporarily unavailable. Ensure sufficient battery and Wi-Fi."
        case .unavailable(let reason):
            notAvailableReason = "Apple Intelligence unavailable: \(String(describing: reason))"
        }
    }
}
