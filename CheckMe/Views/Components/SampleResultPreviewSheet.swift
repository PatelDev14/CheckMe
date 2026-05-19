import SwiftUI

/// Shows a realistic hardcoded preview of what scan results look like for each category.
/// Triggered from each tab's empty state so new users know what to expect before their first scan.
struct SampleResultPreviewSheet: View {
    let category: HealthCategory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    exampleBadge
                    content
                    disclaimer
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Example Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Example badge

    private var exampleBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("EXAMPLE — Not a real scan")
                .font(.caption2).fontWeight(.semibold)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    // MARK: - Content per category

    @ViewBuilder
    private var content: some View {
        switch category {
        case .food:       foodPreview
        case .nutrition:  nutritionPreview
        case .skin:       skinPreview
        }
    }

    // MARK: - Food Preview

    private var foodPreview: some View {
        VStack(spacing: 14) {
            // Rating card
            previewCard {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(.green)
                        Text("Gut Friendly").font(.title3).fontWeight(.bold).foregroundStyle(.green)
                        Spacer()
                        Text("GUT CHECK").font(.caption2).fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                    .padding(16).background(Color.green.opacity(0.08))

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gut Friendly — This cereal contains whole grains and fibre that support digestive health. No major triggers detected for a standard diet.")
                            .font(.subheadline).foregroundStyle(.primary)

                        // Caution badge
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Watch", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                            HStack(spacing: 6) {
                                Text("Sugars")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                                    .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").font(.caption).foregroundStyle(.yellow)
                            Text("Pair with protein to slow sugar absorption and maintain steady energy.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
                    }
                    .padding(16)
                }
            }

            // Ingredients list
            previewCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Ingredients").font(.headline).fontWeight(.bold)
                        Spacer()
                        Text("11").font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }

                    let ingredients = ["Whole grain corn", "Sugars", "Degermed corn meal",
                                       "High monounsaturated canola oil", "Salt", "Calcium carbonate",
                                       "Caramel", "Monoglycerides", "Natural flavour", "Iron", "Niacinamide (vitamin B3)"]
                    ForEach(ingredients.prefix(5), id: \.self) { ing in
                        HStack(spacing: 10) {
                            Image(systemName: ing == "Sugars" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(ing == "Sugars" ? Color.orange : Color.green)
                                .frame(width: 16)
                            Text(ing).font(.subheadline).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(ing == "Sugars" ? Color.orange.opacity(0.06) : Color.secondary.opacity(0.05)))
                    }

                    Text("+ 6 more ingredients")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .padding(14)
            }
        }
    }

    // MARK: - Nutrition Preview

    private var nutritionPreview: some View {
        VStack(spacing: 14) {
            // Macro summary card
            previewCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chocolate Muffin").font(.headline).fontWeight(.bold)
                            Text("Per muffin (100 g)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("NUTRITION").font(.caption2).fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }

                    // Calories big display
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("360").font(.system(size: 42, weight: .heavy))
                            Text("CALORIES").font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Macro rings suggestion
                        HStack(spacing: 16) {
                            macroCircle(label: "Fat", value: "16g", color: .orange)
                            macroCircle(label: "Carbs", value: "49g", color: .purple)
                            macroCircle(label: "Protein", value: "6g", color: .blue)
                        }
                    }
                }
                .padding(16)
            }

            // Nutrient detail rows
            previewCard {
                VStack(spacing: 0) {
                    nutrientRow("Fat / Lipides", "16 g", "21%", .orange)
                    Divider().padding(.leading, 16)
                    nutrientRow("  Saturated", "3 g", "16%", .orange)
                    Divider().padding(.leading, 16)
                    nutrientRow("Carbohydrates", "49 g", "—", .purple)
                    Divider().padding(.leading, 16)
                    nutrientRow("  Sugars / Sucres", "27 g", "27%", .red)
                    Divider().padding(.leading, 16)
                    nutrientRow("Fibre", "2 g", "7%", .green)
                    Divider().padding(.leading, 16)
                    nutrientRow("Protein", "6 g", "—", .blue)
                    Divider().padding(.leading, 16)
                    nutrientRow("Sodium", "340 mg", "15%", .yellow)
                }
            }
        }
    }

    private func macroCircle(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 5).frame(width: 48, height: 48)
                Circle().trim(from: 0, to: 0.55)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                Text(value).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func nutrientRow(_ name: String, _ amount: String, _ dv: String, _ color: Color) -> some View {
        HStack {
            Text(name).font(.subheadline).foregroundStyle(.primary)
            Spacer()
            Text(amount).font(.subheadline).foregroundStyle(.secondary)
            if dv != "—" {
                Text(dv).font(.caption).fontWeight(.semibold).foregroundStyle(color)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Color.clear.frame(width: 40)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Skin Preview

    private var skinPreview: some View {
        VStack(spacing: 14) {
            // Rating card
            previewCard {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
                        Text("Moderate Concern").font(.title3).fontWeight(.bold).foregroundStyle(.orange)
                        Spacer()
                        Text("PERSONAL CARE").font(.caption2).fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                    .padding(16).background(Color.orange.opacity(0.08))

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Moderate Concern — Contains fragrance and denatured alcohol which may cause dryness or irritation for sensitive skin types.")
                            .font(.subheadline).foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Label("Watch", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                            HStack(spacing: 6) {
                                ForEach(["Parfum/Fragrance", "Alcohol Denat."], id: \.self) { item in
                                    Text(item)
                                        .font(.caption).fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                                        .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").font(.caption).foregroundStyle(.yellow)
                            Text("Patch test on your inner arm for 24 hours before applying to your face or sensitive areas.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
                    }
                    .padding(16)
                }
            }

            // Ingredient breakdown
            previewCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredient Breakdown").font(.headline).fontWeight(.bold)

                    ForEach([
                        ("bubbles.and.sparkles.fill", "Surfactants", 2, Color.yellow),
                        ("drop.fill",                 "Humectants",  1, Color.cyan),
                        ("nose.fill",                 "Fragrances",  1, Color.pink),
                        ("lock.fill",                 "Preservatives", 1, Color.orange),
                        ("square.grid.2x2.fill",      "Other",       8, Color.gray),
                    ], id: \.1) { icon, cat, count, color in
                        HStack(spacing: 12) {
                            Image(systemName: icon).font(.caption).foregroundStyle(color).frame(width: 20)
                            Text(cat).font(.subheadline).fontWeight(.medium)
                            Spacer()
                            Text("\(count)").font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(color)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(color.opacity(0.15)))
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.fill.checkmark")
                .font(.caption).foregroundStyle(.secondary)
            Text("Your real results will be personalised to your health profile — ratings and flagged ingredients will reflect your specific allergies, conditions, and skin type.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    // MARK: - Helper

    private func previewCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
