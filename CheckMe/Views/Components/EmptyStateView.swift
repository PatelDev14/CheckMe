//
//  EmptyStateView.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

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
