//
//  SettingsView.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import SwiftUI

struct SettingsView: View {
    @Environment(FoundationModelsManager.self) private var fmManager
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self) private var themeManager

    @State private var showEditSheet = false
    @State private var editStep: Int = 1

    var body: some View {
        @Bindable var themeManager = themeManager

        return NavigationStack {
            List {

                // MARK: Appearance
                Section("Appearance") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            themeManager.selectedTheme = theme
                        } label: {
                            HStack(spacing: 14) {
                                theme.swatchView
                                Text(theme.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if themeManager.selectedTheme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                // MARK: Your Profile
                Section("Your Profile") {
                    ProfileRow(
                        label: "Dietary Preferences",
                        value: profileStore.profile.foodRestrictions.isEmpty ? nil
                            : profileStore.profile.foodRestrictions.joined(separator: ", ")
                    ) { editStep = 1; showEditSheet = true }

                    ProfileRow(
                        label: "Allergies & Gut Health",
                        value: combinedGutValue
                    ) { editStep = 2; showEditSheet = true }

                    ProfileRow(
                        label: "Skin Profile",
                        value: combinedSkinValue
                    ) { editStep = 3; showEditSheet = true }

                    ProfileRow(
                        label: "Extra Notes",
                        value: profileStore.profile.extraNotes.isEmpty ? nil
                            : profileStore.profile.extraNotes
                    ) { editStep = 4; showEditSheet = true }
                }

                // MARK: Apple Intelligence
                Section("Apple Intelligence") {
                    if fmManager.isModelAvailable {
                        Label("Available", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label(fmManager.notAvailableReason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("App") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showEditSheet) {
                OnboardingView(startingStep: editStep, isEditing: true)
            }
        }
    }

    private var combinedGutValue: String? {
        let parts = [
            profileStore.profile.foodAllergies,
            profileStore.profile.digestiveConditions
        ].flatMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var combinedSkinValue: String? {
        var parts: [String] = []
        if !profileStore.profile.skinType.isEmpty { parts.append(profileStore.profile.skinType) }
        parts += profileStore.profile.skinConditions
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Profile Row with inline Edit

private struct ProfileRow: View {
    let label: String
    let value: String?
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline).fontWeight(.medium)
                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Not set")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            Spacer()
            Button("Edit") { onEdit() }
                .font(.caption).fontWeight(.semibold)
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environment(FoundationModelsManager())
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
