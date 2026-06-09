import SwiftUI

// MARK: - Common ingredient suggestions for autocomplete

private let commonIngredientSuggestions: [String] = [
    // Oils & fats
    "Palm Oil", "Palm Kernel Oil", "Hydrogenated Palm Oil", "Partially Hydrogenated Oil",
    "Soybean Oil", "Canola Oil", "Corn Oil", "Cottonseed Oil", "Sunflower Oil",
    "Coconut Oil", "Rapeseed Oil",
    // Sweeteners
    "Aspartame", "Sucralose", "Saccharin", "Acesulfame Potassium", "Acesulfame-K",
    "High Fructose Corn Syrup", "Corn Syrup", "High-Fructose Corn Syrup",
    "Maltodextrin", "Sorbitol", "Xylitol", "Erythritol", "Stevia",
    // Preservatives
    "Sodium Benzoate", "Potassium Benzoate", "Sodium Nitrate", "Sodium Nitrite",
    "BHA", "BHT", "TBHQ", "Propyl Gallate",
    "Sodium Propionate", "Calcium Propionate",
    // Artificial colours
    "Red 40", "Red 3", "Yellow 5", "Yellow 6", "Blue 1", "Blue 2", "Green 3",
    "Tartrazine", "Allura Red", "Sunset Yellow", "Brilliant Blue", "Erythrosine",
    "Carmoisine", "Quinoline Yellow", "Caramel Colour",
    // Flavour enhancers
    "Monosodium Glutamate", "MSG", "Disodium Inosinate", "Disodium Guanylate",
    "Autolyzed Yeast Extract", "Hydrolyzed Vegetable Protein",
    // Emulsifiers
    "Carrageenan", "Polysorbate 80", "Polysorbate 60", "Soy Lecithin",
    "Mono and Diglycerides", "DATEM", "Sodium Stearoyl Lactylate", "Carboxymethylcellulose",
    // Common allergens
    "Gluten", "Wheat", "Wheat Flour", "Barley", "Rye", "Oats",
    "Milk", "Lactose", "Whey", "Casein",
    "Eggs", "Soy", "Soy Protein", "Peanuts", "Tree Nuts", "Almonds",
    "Shellfish", "Fish", "Sesame",
    // Skin / personal care concerns
    "Parabens", "Methylparaben", "Propylparaben", "Butylparaben", "Ethylparaben",
    "Sodium Lauryl Sulfate", "Sodium Laureth Sulfate", "SLS", "SLES",
    "Formaldehyde", "DMDM Hydantoin", "Quaternium-15", "Imidazolidinyl Urea",
    "Phthalates", "Diethyl Phthalate", "Fragrance", "Parfum",
    "Mineral Oil", "Petrolatum", "BHA", "Oxybenzone", "Octinoxate",
    "Polyethylene Glycol", "PEG",
    // Other common flags
    "Artificial Flavour", "Artificial Flavoring", "Natural Flavour",
    "Modified Starch", "Modified Food Starch",
    "Carnauba Wax", "Titanium Dioxide",
]

/// Lets the user maintain a personal ingredient blacklist.
/// Any ingredient added here will always be highlighted with an orange "Blocked" badge
/// in scan results — across both Food and Personal Care tabs — regardless of their health profile.
struct BlacklistView: View {
    @Environment(UserProfileStore.self) private var profileStore

    @State private var newIngredient: String = ""
    @State private var showDuplicateAlert = false
    @FocusState private var fieldFocused: Bool
    @State private var showSuggestions = false

    private var blacklist: [String] { profileStore.profile.blacklistedIngredients }

    // Filtered suggestions: match on any word, exclude already-blacklisted entries
    private var filteredSuggestions: [String] {
        let query = newIngredient.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return [] }
        let lower = query.lowercased()
        let alreadyBlacklisted = Set(blacklist.map { $0.lowercased() })
        return commonIngredientSuggestions.filter {
            $0.lowercased().contains(lower) && !alreadyBlacklisted.contains($0.lowercased())
        }
    }

    var body: some View {
        List {
            // MARK: Add new
            Section {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        TextField("e.g. Palm Oil, Aspartame, Red 40…", text: $newIngredient)
                            .focused($fieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onChange(of: newIngredient) { _, _ in
                                showSuggestions = !filteredSuggestions.isEmpty
                            }
                            .onSubmit { addIngredient() }

                        Button(action: addIngredient) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty
                                                 ? Color.secondary : Color.orange)
                        }
                        .buttonStyle(.plain)
                        .disabled(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 2)

                    // Inline autocomplete suggestions
                    if showSuggestions && fieldFocused {
                        VStack(alignment: .leading, spacing: 0) {
                            Divider().padding(.vertical, 6)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filteredSuggestions.prefix(8), id: \.self) { suggestion in
                                        Button {
                                            newIngredient = suggestion
                                            showSuggestions = false
                                            addIngredient()
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "hand.raised")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                                Text(suggestion)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.primary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.orange.opacity(0.10)))
                                            .overlay(Capsule().stroke(Color.orange.opacity(0.30), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuggestions)
                    }
                }
            } header: {
                Text("Add Ingredient")
            } footer: {
                Text("Type a full or partial name — e.g. \"Palm Oil\" will flag any ingredient containing those words. Suggestions appear as you type.")
            }

            // MARK: Current blacklist
            if blacklist.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.raised.slash.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Blocked Ingredients")
                            .font(.headline)
                        Text("Add any ingredient above and it will be highlighted with an orange badge every time it appears in a scan.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(blacklist, id: \.self) { ingredient in
                        HStack(spacing: 10) {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(width: 18)

                            Text(ingredient)
                                .font(.subheadline)

                            Spacer()

                            Text("Blocked")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteIngredients)
                } header: {
                    HStack {
                        Text("Blocked")
                        Spacer()
                        Text("\(blacklist.count)")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Swipe left on any ingredient to remove it from your blacklist.")
                }
            }
        }
        .navigationTitle("Ingredient Blacklist")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { fieldFocused = false; showSuggestions = false }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !blacklist.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
        .alert("Already Blacklisted", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(newIngredient.trimmingCharacters(in: .whitespaces))\" is already in your blacklist.")
        }
    }

    // MARK: - Actions

    private func addIngredient() {
        let trimmed = newIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Case-insensitive duplicate check
        if blacklist.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            showDuplicateAlert = true
            return
        }

        withAnimation {
            profileStore.profile.blacklistedIngredients.append(trimmed)
        }
        newIngredient = ""
        showSuggestions = false
        fieldFocused = false
    }

    private func deleteIngredients(at offsets: IndexSet) {
        withAnimation {
            profileStore.profile.blacklistedIngredients.remove(atOffsets: offsets)
        }
    }
}

#Preview {
    NavigationStack {
        BlacklistView()
            .environment(UserProfileStore())
    }
}
