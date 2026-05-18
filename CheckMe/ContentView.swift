//
//  ContentView.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            // Global gradient background — sits behind the TabView so every screen
            // gets a consistent subtle tinted gradient instead of a flat dark solid.
            themeManager.selectedTheme.backgroundGradient
                .ignoresSafeArea()

            TabView {
                Tab("Food", systemImage: "fork.knife") {
                    FoodScanView()
                }
                Tab("Nutrition", systemImage: "chart.pie.fill") {
                    NutritionScanView()
                }
                Tab("Personal Care", systemImage: "sparkles") {
                    SkinScanView()
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ScanModel.self, IngredientsModel.self], inMemory: true)
        .environment(FoundationModelsManager())
}
