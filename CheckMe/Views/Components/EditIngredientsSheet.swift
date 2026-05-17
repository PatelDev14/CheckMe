import SwiftUI

// Modal sheet for correcting OCR/AI parsing errors in the ingredient list.
// Presents a fully editable list — rows can be renamed, reordered, deleted,
// and new entries added. Saving triggers a fresh AI analysis.

struct EditIngredientsSheet: View {
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var ingredients: [String]
    @State private var newIngredient = ""
    @State private var editMode: EditMode = .inactive

    init(ingredients: [String], onSave: @escaping ([String]) -> Void) {
        self._ingredients = State(initialValue: ingredients)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.selectedTheme.colors.background.ignoresSafeArea()

                List {
                    Section {
                        ForEach(ingredients.indices, id: \.self) { index in
                            TextField("Ingredient", text: $ingredients[index])
                                .foregroundStyle(.white)
                        }
                        .onDelete { offsets in ingredients.remove(atOffsets: offsets) }
                        .onMove { from, to in ingredients.move(fromOffsets: from, toOffset: to) }
                    } header: {
                        Text("\(ingredients.count) ingredient\(ingredients.count == 1 ? "" : "s") · tap to edit · drag to reorder")
                            .font(.caption)
                    }

                    Section {
                        HStack(spacing: 10) {
                            TextField("New ingredient name", text: $newIngredient)
                                .foregroundStyle(.white)
                                .submitLabel(.done)
                                .onSubmit { commitNew() }
                            if !newIngredient.trimmingCharacters(in: .whitespaces).isEmpty {
                                Button("Add", action: commitNew)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                            }
                        }
                    } header: {
                        Text("Add ingredient")
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
            .navigationTitle("Edit Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editMode = editMode == .active ? .inactive : .active
                    } label: {
                        Text(editMode == .active ? "Done" : "Reorder")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Re-analyze") {
                        let cleaned = ingredients
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onSave(cleaned)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(themeManager.selectedTheme.colors.accent)
                    .disabled(ingredients.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func commitNew() {
        let trimmed = newIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation { ingredients.append(trimmed) }
        newIngredient = ""
    }
}
