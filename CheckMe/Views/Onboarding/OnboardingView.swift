//
//  OnboardingView.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import SwiftUI

struct OnboardingView: View {
    /// When opened from Settings to edit a specific section
    var startingStep: Int = 0
    var isEditing: Bool = false

    @Environment(UserProfileStore.self) private var store
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int
    @State private var didTapButton = false   // distinguishes button tap vs swipe

    private let totalSteps = 6

    init(startingStep: Int = 0, isEditing: Bool = false) {
        self.startingStep = startingStep
        self.isEditing = isEditing
        _step = State(initialValue: startingStep)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(themeManager.selectedTheme.gradient)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.white : Color.white.opacity(0.3))
                            .frame(width: i == step ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 8)

                // Step content — swipe disabled on step 0
                TabView(selection: $step) {
                    WelcomeStep(isEditing: isEditing).tag(0)
                    FoodRestrictionsStep().tag(1)
                    FoodAllergiesAndGutStep().tag(2)
                    SkinProfileStep().tag(3)
                    HealthGoalsStep().tag(4)
                    ExtraNotesStep().tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
                .onChange(of: step) { oldValue, newValue in
                    // Block swipe-left on welcome page — only allow button
                    if oldValue == 0 && newValue != 0 && !didTapButton {
                        withAnimation { step = 0 }
                    }
                    didTapButton = false
                }

                // Continue / Get Started button
                Button {
                    didTapButton = true
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    if step < totalSteps - 1 {
                        withAnimation { step += 1 }
                    } else {
                        complete()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(buttonLabel)
                            .font(.headline).fontWeight(.bold)
                        Image(systemName: step == totalSteps - 1 ? "checkmark" : "arrow.right")
                    }
                    .foregroundStyle(step == totalSteps - 1 ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(step == totalSteps - 1 ? Color.white : Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, isEditing || step != 0 ? 52 : 12)

                // Skip — only on welcome, more prominent
                if step == 0 && !isEditing {
                    Button {
                        complete()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    .padding(.bottom, 44)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var buttonLabel: String {
        if step == totalSteps - 1 {
            return isEditing ? "Save Changes" : "Get Started"
        }
        return "Continue"
    }

    private func complete() {
        if !isEditing { hasCompletedOnboarding = true }
        dismiss()
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let isEditing: Bool

    var body: some View {
        OnboardingStepContainer {
            Image(systemName: "checklist")
                .font(.system(size: 68))
                .foregroundStyle(.white)
                .symbolEffect(.pulse)

            VStack(spacing: 16) {
                Text("Know What You Put In (and On) Your Body")
                    .font(.title).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Scan any ingredient label and get instant, personalized analysis — for your gut and your skin.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                OnboardingFeatureRow(icon: "camera.viewfinder",    text: "Scan food & skincare labels")
                OnboardingFeatureRow(icon: "brain.head.profile",   text: "Apple Intelligence analysis")
                OnboardingFeatureRow(icon: "person.fill.checkmark",text: "Personalized to your needs")
            }
        }
    }
}

// MARK: - Step 2: Food Restrictions

private struct FoodRestrictionsStep: View {
    @Environment(UserProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store
        OnboardingStepContainer {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Dietary Preferences")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Select any that apply to you.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            }

            SelectionGrid(
                options: ProfileOptions.foodRestrictions,
                selected: store.profile.foodRestrictions
            ) { toggle($0, in: &store.profile.foodRestrictions) }
        }
    }

    private func toggle(_ item: String, in list: inout [String]) {
        if list.contains(item) { list.removeAll { $0 == item } } else { list.append(item) }
    }
}

// MARK: - Step 3: Allergies + Gut

private struct FoodAllergiesAndGutStep: View {
    @Environment(UserProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store
        OnboardingStepContainer {
            Image(systemName: "allergens")
                .font(.system(size: 56))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Allergies & Gut Health")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("We'll always flag these in scans.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 16) {
                SectionLabel("Allergies")
                SelectionGrid(options: ProfileOptions.foodAllergies, selected: store.profile.foodAllergies) {
                    toggle($0, in: &store.profile.foodAllergies)
                }

                SectionLabel("Digestive Conditions")
                SelectionGrid(options: ProfileOptions.digestiveConditions, selected: store.profile.digestiveConditions) {
                    toggle($0, in: &store.profile.digestiveConditions)
                }
            }
        }
    }

    private func toggle(_ item: String, in list: inout [String]) {
        if list.contains(item) { list.removeAll { $0 == item } } else { list.append(item) }
    }
}

// MARK: - Step 4: Skin

private struct SkinProfileStep: View {
    @Environment(UserProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store
        OnboardingStepContainer {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Your Skin Profile")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Helps us flag irritants in skincare scans.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 16) {
                SectionLabel("Skin Type")
                // Use same SelectionGrid but single-select behaviour
                FlowLayout(spacing: 8) {
                    ForEach(ProfileOptions.skinTypes, id: \.self) { type in
                        let selected = store.profile.skinType == type
                        Button {
                            store.profile.skinType = selected ? "" : type
                        } label: {
                            Text(type)
                                .font(.subheadline).fontWeight(.medium)   // matches chip grid
                                .foregroundStyle(selected ? .black : .white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selected ? Color.white : Color.white.opacity(0.2))
                                .clipShape(Capsule())
                                .animation(.spring(response: 0.25), value: selected)
                        }
                    }
                }

                SectionLabel("Skin Conditions")
                SelectionGrid(options: ProfileOptions.skinConditions, selected: store.profile.skinConditions) {
                    toggle($0, in: &store.profile.skinConditions)
                }
            }
        }
    }

    private func toggle(_ item: String, in list: inout [String]) {
        if list.contains(item) { list.removeAll { $0 == item } } else { list.append(item) }
    }
}

// MARK: - Step 5: Health Goals

private struct HealthGoalsStep: View {
    @Environment(UserProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store
        OnboardingStepContainer {
            Image(systemName: "target")
                .font(.system(size: 56))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Your Health Goals")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Helps us tailor every analysis to what matters to you.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            SelectionGrid(
                options: ProfileOptions.healthGoals,
                selected: store.profile.healthGoals
            ) { toggle($0, in: &store.profile.healthGoals) }
        }
    }

    private func toggle(_ item: String, in list: inout [String]) {
        if list.contains(item) { list.removeAll { $0 == item } } else { list.append(item) }
    }
}

// MARK: - Step 6: Extra Notes

private struct ExtraNotesStep: View {
    @Environment(UserProfileStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var store = store
        OnboardingStepContainer {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Anything Else?")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Specific ingredients or concerns to always flag.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            TextField("e.g. I react badly to carrageenan, always flag MSG…", text: $store.profile.extraNotes, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .padding()
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focused = false }
                            .fontWeight(.semibold)
                    }
                }

            Text("Saved privately on your device.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Shared Components

struct OnboardingStepContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 16)
                    content
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 100)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline).foregroundStyle(.white)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
    }
}

struct SelectionGrid: View {
    let options: [String]
    let selected: [String]
    let onToggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.contains(option)
                Button { onToggle(option) } label: {
                    Text(option)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(isOn ? .black : .white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(isOn ? Color.white : Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .animation(.spring(response: 0.25), value: isOn)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = (proposal.width ?? 0)
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        // Propose maxWidth so long text wraps within badges rather than overflowing the container.
        let sizeProposal = maxWidth > 0
            ? ProposedViewSize(width: maxWidth, height: nil)
            : ProposedViewSize.unspecified

        for view in subviews {
            let size = view.sizeThatFits(sizeProposal)
            if x + size.width > maxWidth, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        let sizeProposal = ProposedViewSize(width: maxWidth, height: nil)

        for view in subviews {
            let size = view.sizeThatFits(sizeProposal)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(UserProfileStore())
        .environment(ThemeManager())
}
