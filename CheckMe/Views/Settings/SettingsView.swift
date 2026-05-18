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
        NavigationStack {
            List {

                // MARK: Appearance
                Section {
                    // Compact theme dropdown with small gradient swatch
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme")
                            .font(.subheadline).fontWeight(.medium)

                        Menu {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        themeManager.selectedTheme = theme
                                    }
                                } label: {
                                    if themeManager.selectedTheme == theme {
                                        Label(theme.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(theme.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(themeManager.selectedTheme.swatchGradient)
                                    .frame(width: 36, height: 22)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
                                Text(themeManager.selectedTheme.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.vertical, 2)

                } header: {
                    Text("Appearance")
                }

                // MARK: Your Profile
                Section {
                    // Completeness indicator
                    let score = profileStore.profile.completenessScore
                    let total = UserProfile.totalSections
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Profile Completeness")
                                .font(.subheadline).fontWeight(.medium)
                            Spacer()
                            Text("\(score) of \(total) complete")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(score == total ? .green : .secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemFill))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(score == total ? Color.green : Color.accentColor)
                                    .frame(width: geo.size.width * CGFloat(score) / CGFloat(total), height: 6)
                                    .animation(.spring(response: 0.4), value: score)
                            }
                        }
                        .frame(height: 6)

                        if score < total {
                            let missing = ["Dietary", "Gut Health", "Skin", "Goals", "Notes"]
                                .filter { !profileStore.profile.completedSections.contains($0) }
                            Text("Missing: \(missing.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

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
                        label: "Personal Care Profile",
                        value: combinedSkinValue
                    ) { editStep = 3; showEditSheet = true }

                    ProfileRow(
                        label: "Health Goals",
                        value: profileStore.profile.healthGoals.isEmpty ? nil
                            : profileStore.profile.healthGoals.joined(separator: ", ")
                    ) { editStep = 4; showEditSheet = true }

                    ProfileRow(
                        label: "Extra Notes",
                        value: profileStore.profile.extraNotes.isEmpty ? nil
                            : profileStore.profile.extraNotes
                    ) { editStep = 5; showEditSheet = true }
                } header: {
                    Text("Your Profile")
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

// MARK: - Profile Row

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
