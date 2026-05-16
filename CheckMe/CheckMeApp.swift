//
//  CheckMeApp.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import SwiftUI
import SwiftData

@main
struct CheckMeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ScanModel.self,
            GeneralSummaryModel.self,
            SavedGutPrediction.self,
            IngredientsModel.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var fmManager = FoundationModelsManager()
    @State private var profileStore = UserProfileStore()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(fmManager)
        .environment(profileStore)
        .environment(themeManager)
    }
}
