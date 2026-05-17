import SwiftUI
import SwiftData

// Displays the full results of a food scan:
// - Color-coded gut compatibility card at the top
// - Expandable general summary
// - Tappable ingredient chips → IngredientDetailView
// - Reanalyze option if the user updates their profile

struct IngredientsListView: View {
    let scan: ScanModel

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showSummary = false
    @State private var isReanalyzing = false
    @State private var showShareSheet = false
    @State private var reanalysisError: String?

    var body: some View {
        ZStack(alignment: .top) {
            themeManager.selectedTheme.colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Gradient header
                    headerSection

                    VStack(spacing: 16) {
                        // Main gut prediction card
                        gutPredictionCard

                        // General summary (collapsible)
                        if scan.summary != nil {
                            summaryCard
                        }

                        // Ingredient list
                        ingredientsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }

            // Reanalyze progress banner
            if isReanalyzing {
                reanalyzeBanner
            }
        }
        .navigationTitle(scan.itemName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    themeManager.selectedTheme.colors.primary,
                    themeManager.selectedTheme.colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            VStack(spacing: 4) {
                Text(scan.itemName)
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("\(scan.ingredientCount) ingredients · \(scan.dateSaved.shortDisplay)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Gut Prediction Card

    @ViewBuilder
    private var gutPredictionCard: some View {
        if let gutPrediction = scan.gutPrediction {
            let rating = GutRating(from: gutPrediction.prediction)

            VStack(spacing: 0) {
                // Rating header strip
                HStack(spacing: 10) {
                    Image(systemName: rating.icon)
                        .font(.title2)
                        .foregroundStyle(rating.color)
                    Text(rating.label)
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(rating.color)
                    Spacer()
                    // Small badge
                    Text("GUT CHECK")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .padding(16)
                .background(rating.color.opacity(0.12))

                Divider().overlay(rating.color.opacity(0.2))

                // Prediction text
                VStack(alignment: .leading, spacing: 12) {
                    Text(gutPrediction.prediction)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(nil)  // Allow text wrapping
                        .fixedSize(horizontal: false, vertical: true)

                    // Trigger badges — ingredients to avoid
                    if !gutPrediction.triggers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Avoid", systemImage: "xmark.octagon.fill")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.red.opacity(0.8))
                            FlowLayout(spacing: 6) {
                                ForEach(gutPrediction.triggers, id: \.self) { trigger in
                                    Text(trigger)
                                        .font(.caption).fontWeight(.medium)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.red.opacity(0.12)))
                                        .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }

                    // Caution badges — mild concerns to watch
                    if !gutPrediction.cautions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Watch", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.yellow.opacity(0.9))
                            FlowLayout(spacing: 6) {
                                ForEach(gutPrediction.cautions, id: \.self) { caution in
                                    Text(caution)
                                        .font(.caption).fontWeight(.medium)
                                        .foregroundStyle(.yellow)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.yellow.opacity(0.1)))
                                        .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }

                    // Tip row
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                        Text(gutPrediction.tip)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(nil)  // Allow wrapping
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
                }
                .padding(16)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(rating.color.opacity(0.25), lineWidth: 1))

            // Info note about ingredient flagging
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text("Red/Yellow ingredients are flagged based on your profile and general health. Tap any ingredient for details.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.03)))
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            // Toggle header
            Button {
                withAnimation(.spring(response: 0.3)) { showSummary.toggle() }
            } label: {
                HStack {
                    Label("Product Summary", systemImage: "doc.text.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: showSummary ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
            }

            if showSummary, let s = scan.summary {
                VStack(alignment: .leading, spacing: 12) {
                    SummaryRow(icon: "info.circle", label: "Overview", text: s.overview)
                    Divider().overlay(.white.opacity(0.08))
                    SummaryRow(icon: "arrow.triangle.2.circlepath", label: "Digestion", text: s.digestionProcess)
                    Divider().overlay(.white.opacity(0.08))
                    SummaryRow(icon: "list.bullet", label: "Complexity", text: s.complexity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(scan.ingredientCount)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }

            // Each ingredient is a navigation link to IngredientDetailView
            LazyVStack(spacing: 8) {
                ForEach(scan.ingredients, id: \.self) { ingredient in
                    NavigationLink(destination: IngredientDetailView(ingredientName: ingredient, scan: scan)) {
                        IngredientRow(
                            name: ingredient,
                            triggers: scan.gutPrediction?.triggers ?? [],
                            cautions: scan.gutPrediction?.cautions ?? []
                        )
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    Task { await reanalyze() }
                } label: {
                    Label("Re-analyse with current profile", systemImage: "arrow.clockwise")
                }
                Button {
                    shareText()
                } label: {
                    Label("Share Results", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) {
                    deleteScan()
                } label: {
                    Label("Delete Scan", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Reanalyze Banner

    private var reanalyzeBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Re-analysing with your current profile…")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Actions

    @MainActor
    private func reanalyze() async {
        isReanalyzing = true
        let vm = IngredientsViewModel(modelContext: modelContext, profileStore: profileStore)
        await vm.reanalyze(scan: scan)
        isReanalyzing = false
    }

    private func shareText() {
        // Generate a formatted PDF with all scan results
        let pdfData = generatePDF()

        var activityItems: [Any] = [pdfData]

        // Also include a text version for email
        let textSummary = """
        CheckMe Scan Report
        Product: \(scan.itemName)
        Date: \(scan.dateSaved.shortDisplay)

        GUT PREDICTION: \(scan.gutPrediction?.prediction ?? "Not analyzed")
        """
        activityItems.append(textSummary)

        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // Exclude some activity types for better UX
        activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    private func generatePDF() -> Data {
        let pdfWidth: CGFloat = 612   // 8.5 inches at 72 DPI
        let pdfHeight: CGFloat = 792  // 11 inches at 72 DPI
        let margin: CGFloat = 40
        let contentWidth = pdfWidth - (margin * 2)
        let pageBottom = pdfHeight - margin  // usable bottom boundary

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight))

        let data = pdfRenderer.pdfData { context in
            var y: CGFloat = margin
            context.beginPage()

            // Helper: start a new page and reset y if the next block won't fit
            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageBottom {
                    context.beginPage()
                    y = margin
                }
            }

            // Helper: draw text that can span multiple lines and returns the actual height used
            @discardableResult
            func drawText(_ text: String, at xPos: CGFloat, font: UIFont, color: UIColor, maxHeight: CGFloat = 500) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let rect = CGRect(x: xPos, y: y, width: contentWidth - (xPos - margin), height: maxHeight)
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: rect.width, height: maxHeight),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs, context: nil
                )
                let usedHeight = ceil(boundingRect.height) + 4
                ensureSpace(usedHeight)
                (text as NSString).draw(in: CGRect(x: xPos, y: y, width: rect.width, height: usedHeight), withAttributes: attrs)
                return usedHeight
            }

            // Helper: draw a section label
            func drawSection(_ label: String, color: UIColor = .white) {
                ensureSpace(22)
                drawText(label, at: margin, font: UIFont.boldSystemFont(ofSize: 13), color: color)
                y += 20
            }

            // ── Title ────────────────────────────────────────────────
            let titleHeight = drawText("CheckMe Scan Report", at: margin, font: UIFont.boldSystemFont(ofSize: 20), color: .white)
            y += titleHeight + 4

            let nameHeight = drawText(scan.itemName, at: margin, font: UIFont.boldSystemFont(ofSize: 15), color: .white)
            y += nameHeight + 2

            let dateHeight = drawText("Scanned: \(scan.dateSaved.shortDisplay)", at: margin, font: UIFont.systemFont(ofSize: 11), color: .lightGray)
            y += dateHeight + 16

            // ── Gut Prediction ───────────────────────────────────────
            if let gut = scan.gutPrediction {
                drawSection("GUT PREDICTION")

                let predHeight = drawText(gut.prediction, at: margin, font: UIFont.systemFont(ofSize: 12), color: .white)
                y += predHeight + 8

                if !gut.triggers.isEmpty {
                    ensureSpace(40)
                    drawText("AVOID:", at: margin, font: UIFont.boldSystemFont(ofSize: 12), color: UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
                    y += 16
                    let triggerHeight = drawText(gut.triggers.joined(separator: " · "), at: margin + 8, font: UIFont.systemFont(ofSize: 11), color: .white)
                    y += triggerHeight + 8
                }

                if !gut.cautions.isEmpty {
                    ensureSpace(40)
                    drawText("WATCH:", at: margin, font: UIFont.boldSystemFont(ofSize: 12), color: UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1))
                    y += 16
                    let cautionHeight = drawText(gut.cautions.joined(separator: " · "), at: margin + 8, font: UIFont.systemFont(ofSize: 11), color: .white)
                    y += cautionHeight + 8
                }

                ensureSpace(40)
                drawText("TIP:", at: margin, font: UIFont.boldSystemFont(ofSize: 12), color: UIColor(red: 1, green: 0.84, blue: 0, alpha: 1))
                y += 16
                let tipHeight = drawText(gut.tip, at: margin + 8, font: UIFont.systemFont(ofSize: 11), color: .lightGray)
                y += tipHeight + 16
            }

            // ── Summary ──────────────────────────────────────────────
            if let summary = scan.summary {
                drawSection("SUMMARY")

                let overviewH = drawText("Overview: \(summary.overview)", at: margin, font: UIFont.systemFont(ofSize: 11), color: .lightGray)
                y += overviewH + 6

                let digestionH = drawText("Digestion: \(summary.digestionProcess)", at: margin, font: UIFont.systemFont(ofSize: 11), color: .lightGray)
                y += digestionH + 6

                let complexH = drawText("Complexity: \(summary.complexity)", at: margin, font: UIFont.systemFont(ofSize: 11), color: .lightGray)
                y += complexH + 16
            }

            // ── Ingredients ──────────────────────────────────────────
            drawSection("INGREDIENTS (\(scan.ingredientCount))")

            let ingredientFont = UIFont.systemFont(ofSize: 10)
            for (index, ingredient) in scan.ingredients.enumerated() {
                let line = "\(index + 1). \(ingredient)"
                ensureSpace(16)
                let lineH = drawText(line, at: margin, font: ingredientFont, color: .lightGray)
                y += lineH + 2
            }
        }

        return data
    }

    private func deleteScan() {
        // Dismiss first so SwiftUI tears down this view before the model is invalidated.
        // Accessing any lazy-loaded property (like ingredients) on a deleted SwiftData
        // object causes a fatal "detached from context" fault.
        dismiss()
        Task { @MainActor in
            modelContext.delete(scan)
            try? modelContext.save()
        }
    }
}

// MARK: - Ingredient Status

private enum IngredientStatus {
    case safe       // green — no concerns for this user
    case caution    // yellow — mild concern
    case trigger    // red — should avoid

    var color: Color {
        switch self { case .safe: .green; case .caution: .yellow; case .trigger: .red }
    }

    var icon: String {
        switch self { case .safe: "checkmark.circle.fill"; case .caution: "exclamationmark.triangle.fill"; case .trigger: "xmark.octagon.fill" }
    }

    var label: String {
        switch self { case .safe: "OK"; case .caution: "Caution"; case .trigger: "Avoid" }
    }
}

// MARK: - Ingredient Row

private struct IngredientRow: View {
    let name: String
    let triggers: [String]
    let cautions: [String]

    private var status: IngredientStatus {
        let lower = name.lowercased()
        if triggers.contains(where: { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }) {
            return .trigger
        }
        if cautions.contains(where: { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }) {
            return .caution
        }
        return .safe
    }

    var body: some View {
        HStack(spacing: 10) {
            // Status icon with fixed width keeps names aligned
            Image(systemName: status.icon)
                .font(.caption)
                .foregroundStyle(status.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Brief reason why flagged (guides user to tap for more info)
                if status != .safe {
                    Text("Tap for details")
                        .font(.caption2)
                        .foregroundStyle(status.color.opacity(0.8))
                }
            }

            Spacer()

            // Status label badge — only shown for non-safe
            if status != .safe {
                Text(status.label)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(status.color.opacity(0.12)))
            }

            Image(systemName: "info.circle.fill")
                .font(.caption2)
                .foregroundStyle(status.color.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(status == .safe
                    ? AnyShapeStyle(Color.white.opacity(0.05))
                    : AnyShapeStyle(status.color.opacity(0.07))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(status == .safe ? Color.white.opacity(0.08) : status.color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let icon: String
    let label: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.45))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

// MARK: - Gut Rating Helper

/// Parses the AI's prediction string to extract a rating enum for color/icon/label.
private struct GutRating {
    let label: String
    let color: Color
    let icon: String

    init(from prediction: String) {
        let lower = prediction.lowercased()
        if lower.contains("gut friendly") {
            label = "Gut Friendly"; color = .green; icon = "checkmark.seal.fill"
        } else if lower.contains("moderate risk") {
            label = "Moderate Risk"; color = .orange; icon = "exclamationmark.triangle.fill"
        } else if lower.contains("high risk") {
            label = "High Risk"; color = .red; icon = "xmark.octagon.fill"
        } else {
            label = "Unknown"; color = .gray; icon = "questionmark.circle.fill"
        }
    }
}
