import SwiftUI
import SwiftData

struct NutritionResultsView: View {
    let scan: ScanModel

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var servingsMultiplier: Double = 1.0
    @State private var editedName: String = ""
    @State private var isEditingName = false
    @State private var showingPhoto = false
    @FocusState private var nameFocused: Bool

    private let accentColor = Color(red: 0.55, green: 0.45, blue: 0.95)
    private let servingOptions: [(label: String, value: Double)] = [
        ("½×", 0.5), ("1×", 1.0), ("1½×", 1.5), ("2×", 2.0)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            themeManager.selectedTheme.colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .onTapGesture { if isEditingName { commitName() } }

                    VStack(spacing: 16) {
                        if let nutrition = scan.nutritionFacts {
                            capturedPhotoCard
                            servingPickerCard(nutrition)
                            NutritionFactsCard(facts: nutrition, servingsMultiplier: servingsMultiplier, startsExpanded: true)

                            if !nutrition.fillLayerNames.isEmpty {
                                ContainerFillView(
                                    containerType: nutrition.containerType,
                                    layerNames: nutrition.fillLayerNames,
                                    layerPercents: nutrition.fillLayerPercents
                                )
                            }

                            MicronutrientsView(nutrition: nutrition, servingsMultiplier: servingsMultiplier)

                            if !nutrition.aiInsight.isEmpty {
                                insightCard(nutrition.aiInsight)
                            }
                        } else {
                            noDataCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(scan.itemName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { editedName = scan.itemName }
        .onChange(of: nameFocused) { _, focused in
            if !focused && isEditingName { commitName() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [accentColor.opacity(0.6), themeManager.selectedTheme.colors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)

            VStack(spacing: 4) {
                if isEditingName {
                    HStack(spacing: 6) {
                        TextField("Product name", text: $editedName)
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .focused($nameFocused)
                            .onSubmit { commitName() }
                        if !editedName.isEmpty {
                            Button { editedName = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                                    .font(.body)
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack(spacing: 6) {
                        Text(scan.itemName)
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Image(systemName: "pencil")
                            .font(.caption).foregroundStyle(.white.opacity(0.45))
                    }
                    .onTapGesture {
                        editedName = scan.itemName
                        isEditingName = true
                        nameFocused = true
                    }
                }

                if let nutrition = scan.nutritionFacts {
                    HStack(spacing: 12) {
                        Label("\(Int(nutrition.calories * servingsMultiplier)) cal", systemImage: "flame.fill")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(accentColor)
                        Text("·").foregroundStyle(.white.opacity(0.3))
                        Text("\(servingsMultiplier == 1.0 ? "Per" : "\(formatMultiplier(servingsMultiplier)) ×") \(nutrition.servingSize)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("·").foregroundStyle(.white.opacity(0.3))
                        Text(scan.dateSaved.shortDisplay)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Captured Photo

    @ViewBuilder
    private var capturedPhotoCard: some View {
        if let path = scan.capturedImagePath,
           let image = loadImage(path) {
            Button { showingPhoto = true } label: {
                HStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("View Scanned Label")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text("Tap to see the original photo")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.white.opacity(0.3))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPhoto) {
                fullScreenPhoto(image)
            }
        }
    }

    private func fullScreenPhoto(_ image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            Button { showingPhoto = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(20)
            }
        }
    }

    private func loadImage(_ filename: String) -> UIImage? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Serving Picker

    private func servingPickerCard(_ nutrition: SavedNutritionFacts) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How much did you have?")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(servingOptions, id: \.label) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            servingsMultiplier = option.value
                        }
                    } label: {
                        Text(option.label)
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(servingsMultiplier == option.value
                                          ? accentColor
                                          : accentColor.opacity(0.12))
                            )
                            .foregroundStyle(servingsMultiplier == option.value
                                             ? .white
                                             : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Insight Card

    private func insightCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(accentColor)
                Text("Macro Insight")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - No Data

    private var noDataCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title).foregroundStyle(.orange)
            Text("No nutrition data found")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
            Text("The Nutrition Facts panel wasn't detected in this scan.")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(role: .destructive) { deleteScan() } label: {
                    Label("Delete Scan", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.white)
            }
        }
    }

    private func commitName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            scan.itemName = trimmed
            editedName = trimmed
            do {
                try modelContext.save()
            } catch {
                scan.itemName = editedName
            }
        }
        isEditingName = false
        nameFocused = false
    }

    private func deleteScan() {
        dismiss()
        Task { @MainActor in
            modelContext.delete(scan)
            try? modelContext.save()
        }
    }

    private func formatMultiplier(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }
}
