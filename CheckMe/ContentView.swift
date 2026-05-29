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
    @Environment(FoundationModelsManager.self) private var fmManager

    var body: some View {
        ZStack {
            // Animated Aurora background — sits behind the TabView so every screen
            // gets a living, breathing tinted background instead of a flat dark solid.
            AnimatedThemeBackground(theme: themeManager.selectedTheme)

            if fmManager.isModelAvailable {
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
            } else {
                AIUnavailableView()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            if !hasCompletedOnboarding && fmManager.isModelAvailable {
                showOnboarding = true
            }
        }
    }
}

// MARK: - Apple Intelligence Gate

private struct AIUnavailableView: View {
    @Environment(FoundationModelsManager.self) private var fmManager
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            AnimatedThemeBackground(theme: themeManager.selectedTheme)

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                }

                // Text
                VStack(spacing: 12) {
                    Text("Apple Intelligence Required")
                        .font(.title2).fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(fmManager.notAvailableReason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Requirements card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Requirements")
                        .font(.headline)

                    RequirementRow(icon: "iphone", text: "iPhone 15 Pro, 15 Pro Max, or later")
                    RequirementRow(icon: "gear", text: "iOS 18.1 or later")
                    RequirementRow(icon: "brain.head.profile", text: "Apple Intelligence enabled in Settings")
                    RequirementRow(icon: "globe", text: "Device language set to English (US)")
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.headline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        fmManager.checkIsAvailable()
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct RequirementRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ScanModel.self, IngredientsModel.self], inMemory: true)
        .environment(FoundationModelsManager())
}
