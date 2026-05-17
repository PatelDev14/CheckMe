import Foundation
import SwiftUI

extension Date {
    var shortDisplay: String {
        formatted(date: .abbreviated, time: .shortened)
    }

    var dayDisplay: String {
        formatted(date: .complete, time: .omitted)
    }
}

extension Color {
    static let appPrimary = Color.green
    static let appAccent  = Color.teal
}
