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
    @State private var showEditSheet = false
    @State private var reanalysisError: String?
    @State private var ingredientViewMode: IngredientViewMode = .list
    @State private var editedName: String = ""
    @State private var isEditingName = false
    @State private var showingPhoto = false
    @FocusState private var nameFocused: Bool

    private enum IngredientViewMode: String, CaseIterable {
        case list      = "List"
        case breakdown = "Breakdown"
        var icon: String { self == .list ? "list.bullet" : "chart.bar.fill" }
    }

    var body: some View {
        ZStack(alignment: .top) {
            themeManager.selectedTheme.colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Gradient header
                    headerSection
                        .onTapGesture { if isEditingName { commitName() } }

                    VStack(spacing: 16) {
                        capturedPhotoCard

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
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(scan.itemName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { editedName = scan.itemName }
        .onChange(of: nameFocused) { _, focused in
            if !focused && isEditingName { commitName() }
        }
        .sheet(isPresented: $showEditSheet) {
            EditIngredientsSheet(ingredients: scan.ingredients) { updatedIngredients in
                scan.ingredients = updatedIngredients
                scan.ingredientCount = updatedIngredients.count
                try? modelContext.save()
                Task { await reanalyze() }
            }
            .environment(themeManager)
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
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPhoto) {
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
        }
    }

    private func loadImage(_ filename: String) -> UIImage? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
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
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    if !gutPrediction.triggers.isEmpty {
                        triggerBadgesSection(gutPrediction.triggers)
                    }

                    if !gutPrediction.cautions.isEmpty {
                        cautionBadgesSection(gutPrediction.cautions)
                    }

                    tipRow(gutPrediction.tip)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
            // Header with count + List/Breakdown toggle
            HStack(spacing: 10) {
                Text("Ingredients")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(.white)

                Spacer()

                // Segment toggle
                HStack(spacing: 0) {
                    ForEach(IngredientViewMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                ingredientViewMode = mode
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.caption2)
                                Text(mode.rawValue)
                                    .font(.caption2).fontWeight(.medium)
                            }
                            .foregroundStyle(ingredientViewMode == mode ? .black : .white.opacity(0.5))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                Capsule().fill(
                                    ingredientViewMode == mode
                                        ? themeManager.selectedTheme.colors.accent
                                        : Color.clear
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(.white.opacity(0.08)))

                Text("\(scan.ingredientCount)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }

            // Content switches between flat list and animated breakdown
            if ingredientViewMode == .list {
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
                .transition(.opacity)
            } else {
                AnimatedIngredientBreakdownView(
                    scan: scan,
                    triggers: scan.gutPrediction?.triggers ?? [],
                    cautions: scan.gutPrediction?.cautions ?? []
                )
                .transition(.opacity)
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
                    showEditSheet = true
                } label: {
                    Label("Edit Ingredients", systemImage: "pencil")
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
        let pdfWidth: CGFloat = 612
        let pdfHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pdfWidth - (margin * 2)
        let pageBottom = pdfHeight - margin

        // Colors — dark text on white background so the PDF is actually readable
        let ink       = UIColor(white: 0.10, alpha: 1)
        let subInk    = UIColor(white: 0.35, alpha: 1)
        let faintInk  = UIColor(white: 0.55, alpha: 1)
        let divider   = UIColor(white: 0.85, alpha: 1)

        let gut = scan.gutPrediction
        let ratingColor: UIColor = {
            let p = gut?.prediction.lowercased() ?? ""
            if p.contains("gut friendly")  { return UIColor(red: 0.18, green: 0.70, blue: 0.34, alpha: 1) }
            if p.contains("moderate risk") { return UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1) }
            if p.contains("high risk")     { return UIColor(red: 0.90, green: 0.23, blue: 0.23, alpha: 1) }
            return UIColor(white: 0.5, alpha: 1)
        }()

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight))

        return pdfRenderer.pdfData { ctx in
            var y: CGFloat = margin
            ctx.beginPage()

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageBottom {
                    ctx.beginPage()
                    y = margin
                }
            }

            @discardableResult
            func draw(_ text: String, x xPos: CGFloat, font: UIFont, color: UIColor, maxH: CGFloat = 600) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let w = contentWidth - (xPos - margin)
                let br = (text as NSString).boundingRect(
                    with: CGSize(width: w, height: maxH),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs, context: nil
                )
                let h = ceil(br.height) + 2
                ensureSpace(h)
                (text as NSString).draw(in: CGRect(x: xPos, y: y, width: w, height: h), withAttributes: attrs)
                return h
            }

            func drawDivider() {
                ensureSpace(12)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: y + 6))
                path.addLine(to: CGPoint(x: pdfWidth - margin, y: y + 6))
                divider.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                y += 12
            }

            func drawSectionHeader(_ text: String) {
                ensureSpace(30)
                y += 8
                let h = draw(text, x: margin, font: UIFont.boldSystemFont(ofSize: 11), color: faintInk)
                y += h + 4
                drawDivider()
            }

            // ── App header ─────────────────────────────────────────
            y += draw("CheckMe", x: margin, font: UIFont.boldSystemFont(ofSize: 11), color: faintInk) + 2
            y += draw(scan.itemName, x: margin, font: UIFont.boldSystemFont(ofSize: 22), color: ink) + 2
            y += draw("Food · Scanned \(scan.dateSaved.shortDisplay)", x: margin, font: UIFont.systemFont(ofSize: 11), color: faintInk) + 4
            drawDivider()
            y += 4

            // ── Gut rating pill ─────────────────────────────────────
            if let gut {
                let ratingText = GutRating(from: gut.prediction).label
                let pillFont = UIFont.boldSystemFont(ofSize: 13)
                let pillAttrs: [NSAttributedString.Key: Any] = [.font: pillFont, .foregroundColor: UIColor.white]
                let pillSize = (ratingText as NSString).size(withAttributes: pillAttrs)
                let pillPadH: CGFloat = 14, pillPadV: CGFloat = 6
                let pillW = pillSize.width + pillPadH * 2
                let pillH = pillSize.height + pillPadV * 2
                ensureSpace(pillH + 10)
                let pillRect = CGRect(x: margin, y: y, width: pillW, height: pillH)
                let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2)
                ratingColor.setFill(); pillPath.fill()
                (ratingText as NSString).draw(at: CGPoint(x: margin + pillPadH, y: y + pillPadV), withAttributes: pillAttrs)
                y += pillH + 10

                y += draw(gut.prediction, x: margin, font: UIFont.systemFont(ofSize: 12), color: subInk) + 10

                if !gut.triggers.isEmpty {
                    y += draw("AVOID FOR YOU", x: margin, font: UIFont.boldSystemFont(ofSize: 10), color: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)) + 4
                    y += draw(gut.triggers.map { "• \($0)" }.joined(separator: "\n"), x: margin + 8, font: UIFont.systemFont(ofSize: 11), color: subInk) + 8
                }
                if !gut.cautions.isEmpty {
                    y += draw("WATCH", x: margin, font: UIFont.boldSystemFont(ofSize: 10), color: UIColor(red: 0.80, green: 0.50, blue: 0.10, alpha: 1)) + 4
                    y += draw(gut.cautions.map { "• \($0)" }.joined(separator: "\n"), x: margin + 8, font: UIFont.systemFont(ofSize: 11), color: subInk) + 8
                }
                y += draw("TIP  \(gut.tip)", x: margin, font: UIFont.italicSystemFont(ofSize: 11), color: faintInk) + 8
            }

            // ── Summary ─────────────────────────────────────────────
            if let s = scan.summary {
                drawSectionHeader("PRODUCT SUMMARY")
                y += draw(s.overview, x: margin, font: UIFont.systemFont(ofSize: 11), color: subInk) + 6
                y += draw("Digestion: \(s.digestionProcess)", x: margin, font: UIFont.systemFont(ofSize: 11), color: subInk) + 6
                y += draw("Complexity: \(s.complexity)", x: margin, font: UIFont.systemFont(ofSize: 11), color: subInk) + 6
            }

            // ── Ingredients ──────────────────────────────────────────
            drawSectionHeader("INGREDIENTS  (\(scan.ingredientCount))")

            let iFont = UIFont.systemFont(ofSize: 10)
            for (i, ingredient) in scan.ingredients.enumerated() {
                ensureSpace(15)
                y += draw("\(i + 1).  \(ingredient)", x: margin, font: iFont, color: subInk) + 3
            }

            // ── Footer — drawn directly at the bottom of the current page.
            // Do NOT call draw() here: that goes through ensureSpace() and would
            // start a fresh page whenever y is already near pageBottom.
            let footerFont = UIFont.systemFont(ofSize: 9)
            let footerText = "Generated by CheckMe · \(scan.dateSaved.shortDisplay)"
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: faintInk]
            let footerH = ceil(footerFont.lineHeight) + 2
            (footerText as NSString).draw(
                in: CGRect(x: margin, y: pageBottom - footerH, width: contentWidth, height: footerH + 4),
                withAttributes: footerAttrs
            )
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
        // Dismiss first so SwiftUI tears down this view before the model is invalidated.
        // Accessing any lazy-loaded property (like ingredients) on a deleted SwiftData
        // object causes a fatal "detached from context" fault.
        dismiss()
        Task { @MainActor in
            modelContext.delete(scan)
            try? modelContext.save()
        }
    }

    // MARK: - Badge Sections (extracted to reduce type-checker complexity)

    private func triggerBadgesSection(_ triggers: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Avoid", systemImage: "xmark.octagon.fill")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.red.opacity(0.8))
            FlowLayout(spacing: 6) {
                ForEach(triggers, id: \.self) { trigger in
                    Text(trigger)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.red)
                        .lineLimit(nil)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cautionBadgesSection(_ cautions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Watch", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.yellow.opacity(0.9))
            FlowLayout(spacing: 6) {
                ForEach(cautions, id: \.self) { caution in
                    Text(caution)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.yellow)
                        .lineLimit(nil)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow.opacity(0.1)))
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tipRow(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .lineLimit(1)
            Text(tip)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
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
