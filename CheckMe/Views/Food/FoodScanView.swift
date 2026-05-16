//
//  FoodScanView.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import SwiftUI
import SwiftData

struct FoodScanView: View {
    @Query(
        filter: #Predicate<ScanModel> { $0.category == "Food" },
        sort: \ScanModel.dateSaved,
        order: .reverse
    )
    private var scans: [ScanModel]

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    ContentUnavailableView(
                        "No Food Scans Yet",
                        systemImage: "camera.viewfinder",
                        description: Text("Scan a food label to see if it's safe for your stomach.")
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
            .navigationTitle("Food Scans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Scan", systemImage: "camera.viewfinder") {
                        // Camera flow — implemented in feature/food-scanning
                    }
                }
            }
        }
    }
}

#Preview {
    FoodScanView()
        .modelContainer(for: ScanModel.self, inMemory: true)
        .environment(FoundationModelsManager())
}
