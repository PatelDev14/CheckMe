import Foundation
import FoundationModels

@Observable
class FoundationModelsManager {
    var notAvailableReason = "Checking for model availability."
    /// True only when the hardware itself is ineligible (e.g. iPhone 14).
    /// Used to hide the "Open Settings" button, which is useless in that case.
    var deviceIneligible = false

    var isModelAvailable: Bool {
        notAvailableReason.isEmpty
    }

    init() {
        checkIsAvailable()
    }

    func checkIsAvailable() {
        deviceIneligible = false
        switch SystemLanguageModel.default.availability {
        case .available:
            notAvailableReason = ""
        case .unavailable(.appleIntelligenceNotEnabled):
            notAvailableReason = "Apple Intelligence is turned off. Go to Settings → Apple Intelligence & Siri and enable it."
        case .unavailable(.deviceNotEligible):
            deviceIneligible = true
            notAvailableReason = "Your iPhone model doesn't support Apple Intelligence. A minimum of iPhone 15 Pro is required — iPhone 14 and standard iPhone 15 are not eligible, regardless of iOS version."
        case .unavailable(.modelNotReady):
            notAvailableReason = "Apple Intelligence is still downloading. Connect to Wi-Fi, plug in your device, and check back in a few minutes."
        case .unavailable(let reason):
            notAvailableReason = "Apple Intelligence is unavailable (\(String(describing: reason))). Try restarting your device."
        }
    }
}
