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

                // MARK: Help & FAQ
                Section("Help") {
                    NavigationLink(destination: FAQView()) {
                        Label("FAQ & Tips", systemImage: "questionmark.circle.fill")
                    }
                    NavigationLink(destination: FeedbackView()) {
                        Label("Send Feedback", systemImage: "envelope.fill")
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

// MARK: - FAQ View

struct FAQView: View {
    public struct FAQItem: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    private let items: [FAQItem] = [
        FAQItem(
            question: "How does CheckMe work?",
            answer: "CheckMe uses your iPhone's camera to read ingredient labels via OCR (optical character recognition). It then passes the ingredients to Apple Intelligence — the on-device AI — to analyse them against your personal profile. Everything runs locally on your device."
        ),
        FAQItem(
            question: "Is my data private?",
            answer: "Yes. All your scans, profile data, and analysis results are stored only on your device using SwiftData. Nothing is sent to external servers. Your health profile never leaves your iPhone."
        ),
        FAQItem(
            question: "Why do I need Apple Intelligence enabled?",
            answer: "CheckMe's ingredient analysis is powered by Apple Intelligence (Foundation Models). If it's not available, you can enable it in Settings → Apple Intelligence & Siri. Apple Intelligence is available on iPhone 15 Pro and later (or devices with at least 8 GB RAM running iOS 18+)."
        ),
        FAQItem(
            question: "How accurate is the analysis?",
            answer: "The analysis is based on established ingredient science and your personal profile. It's designed to help you make more informed choices — not to replace professional medical advice. Always consult a healthcare provider for medical decisions."
        ),
        FAQItem(
            question: "Why does the product say 'Unknown Product'?",
            answer: "This means the product name wasn't clearly visible or readable in the scanned text. The ingredient analysis still works correctly. You can rename the product by tapping the pencil icon on the results screen."
        ),
        FAQItem(
            question: "What's the difference between triggers and cautions?",
            answer: "Triggers (red) are ingredients clearly problematic for your profile — allergens, known digestive irritants, or skin irritants you should avoid. Cautions (yellow) are mild concerns worth monitoring but not necessarily harmful in small amounts."
        ),
        FAQItem(
            question: "How do I get the best scan results?",
            answer: "Good lighting makes the biggest difference. Hold your phone steady and ensure the label fills the camera frame. Use the crop tool to focus on just the ingredient list. If a scan fails, try again with the flash on or in better light."
        ),
        FAQItem(
            question: "Why does my Food scan show fewer ingredients than the label?",
            answer: "OCR may occasionally miss ingredients if the label is blurry, curved, or low contrast. You can manually edit the ingredient list by tapping ··· → Edit Ingredients on the results screen, then re-analyse."
        ),
        FAQItem(
            question: "Can I re-analyse a scan after updating my profile?",
            answer: "Yes! On any scan results screen, tap ··· (top right) → Re-analyse with current profile. This will re-run the AI analysis using your updated profile data."
        ),
        FAQItem(
            question: "Does CheckMe work without an internet connection?",
            answer: "Yes — CheckMe works completely offline. All processing happens on-device using Apple Intelligence and your iPhone's camera. No internet connection is required."
        ),
    ]

    @State private var expandedID: UUID?

    var body: some View {
        List {
            Section {
                Text("Find answers to common questions about CheckMe below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(items) { item in
                    FAQRowView(item: item, expandedID: $expandedID)
                }
            }
        }
        .navigationTitle("FAQ & Tips")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct FAQRowView: View {
    let item: FAQView.FAQItem
    @Binding var expandedID: UUID?

    private var isExpanded: Bool { expandedID == item.id }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                expandedID = isExpanded ? nil : item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                        .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                        .font(.subheadline)
                        .padding(.top, 1)

                    Text(item.question)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }

                if isExpanded {
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 28)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    // ⚠️ Replace with your actual support email address
    private let supportEmail = "devp1400@gmail.com"

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case bug         = "Bug Report"
        case feature     = "Feature Request"
        case general     = "General Feedback"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .bug:     return "ladybug.fill"
            case .feature: return "lightbulb.fill"
            case .general: return "bubble.left.fill"
            }
        }
    }

    @State private var category: FeedbackCategory = .general
    @State private var message = ""
    @State private var showCopiedToast = false
    @State private var showMailUnavailableAlert = false
    @FocusState private var messageFocused: Bool

    private var hasMessage: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            // Category
            Section("What kind of feedback?") {
                Picker("Category", selection: $category) {
                    ForEach(FeedbackCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            // Message
            Section {
                TextField("Describe the issue, idea, or experience…", text: $message, axis: .vertical)
                    .lineLimit(5, reservesSpace: true)
                    .focused($messageFocused)
                    .submitLabel(.done)
                    .onSubmit { messageFocused = false }
            } header: {
                Text("Your message")
            } footer: {
                Text("Be as specific as possible — steps to reproduce a bug, or the feature you'd like to see.")
            }

            // Actions
            Section {
                Button {
                    messageFocused = false
                    sendFeedback()
                } label: {
                    Label("Send via Mail", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .disabled(!hasMessage)
                .tint(.accentColor)

                Button {
                    messageFocused = false
                    copyToClipboard()
                } label: {
                    Label(
                        showCopiedToast ? "Copied!" : "Copy to Clipboard",
                        systemImage: showCopiedToast ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(!hasMessage)
                .tint(showCopiedToast ? .green : .secondary)
            } footer: {
                if !hasMessage {
                    Text("Write a message above to enable sending.")
                } else {
                    Text("Mail opens pre-filled — just tap Send. No Apple Mail? Use Copy to Clipboard instead.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { messageFocused = false }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .alert("Mail Not Available", isPresented: $showMailUnavailableAlert) {
            Button("Copy Instead") { copyToClipboard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apple Mail isn't set up on this device. Use Copy to Clipboard and paste into your preferred email app.")
        }
    }

    private func sendFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: category.rawValue),
            URLQueryItem(name: "body", value: message),
        ]

        guard let url = components.url else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                showMailUnavailableAlert = true
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = message
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }
}

#Preview {
    SettingsView()
        .environment(FoundationModelsManager())
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
