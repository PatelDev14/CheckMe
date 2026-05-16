//
//  SkinScanView.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import SwiftUI
import SwiftData

struct SkinScanView: View {
    @Query(
        filter: #Predicate<ScanModel> { $0.category == "Skin" },
        sort: \ScanModel.dateSaved,
        order: .reverse
    )
    private var scans: [ScanModel]

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    ContentUnavailableView(
                        "No Skin Scans Yet",
                        systemImage: "camera.viewfinder",
                        description: Text("Scan a skincare label to analyze its ingredients.")
                    )
                } else {
                    List(scans) { scan in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scan.itemName)
                                .font(.headline)
                            Text("\(scan.ingredients.count) ingredients · \(scan.dateSaved.shortDisplay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Skin Scans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Scan", systemImage: "camera.viewfinder") {
                        // Camera flow — implemented in feature/skin-scanning
                    }
                }
            }
        }
    }
}

#Preview {
    SkinScanView()
        .modelContainer(for: ScanModel.self, inMemory: true)
        .environment(FoundationModelsManager())
}
