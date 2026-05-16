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

    var body: some View {
        TabView {
            Tab("Food", systemImage: "fork.knife") {
                FoodScanView()
            }
            Tab("Skin", systemImage: "sparkles") {
                SkinScanView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
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
