import SwiftUI

struct EmptyStateView: View {
    let label: String
    var systemImage: String = "tray"

    var body: some View {
        ContentUnavailableView(label, systemImage: systemImage)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    EmptyStateView(label: "Nothing here yet")
}
