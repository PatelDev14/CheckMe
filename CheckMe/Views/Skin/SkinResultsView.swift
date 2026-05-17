import SwiftUI
import SwiftData

struct SkinResultsView: View {
    let scan: ScanModel

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var isReanalyzing = false
    @State private var showEditSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            themeManager.selectedTheme.colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 16) {
                        skinPredictionCard
                        ingredientsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }

            if isReanalyzing {
                reanalyzeBanner
            }
        }
        .navigationTitle(scan.itemName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
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

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [themeManager.selectedTheme.colors.primary, themeManager.selectedTheme.colors.background],
                startPoint: .top, endPoint: .bottom
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

    // MARK: - Skin Prediction Card

    @ViewBuilder
    private var skinPredictionCard: some View {
        if let skinPrediction = scan.skinPrediction {
            let rating = SkinRating(from: skinPrediction.rating)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: rating.icon)
                        .font(.title2)
                        .foregroundStyle(rating.color)
                    Text(rating.label)
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(rating.color)
                    Spacer()
                    Text("SKIN CHECK")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .padding(16)
                .background(rating.color.opacity(0.12))

                Divider().overlay(rating.color.opacity(0.2))

                VStack(alignment: .leading, spacing: 12) {
                    Text(skinPrediction.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    if !skinPrediction.irritants.isEmpty {
                        irritantBadgesSection(skinPrediction.irritants)
                    }

                    if !skinPrediction.cautions.isEmpty {
                        cautionBadgesSection(skinPrediction.cautions)
                    }

                    tipRow(skinPrediction.tip)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(themeManager.selectedTheme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(rating.color.opacity(0.25), lineWidth: 1))

            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                Text("Red/Yellow ingredients are flagged based on your skin profile. Tap any ingredient for details.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.03)))
        }
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                Spacer()
                Text("\(scan.ingredientCount)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }

            LazyVStack(spacing: 8) {
                ForEach(scan.ingredients, id: \.self) { ingredient in
                    NavigationLink(destination: SkinIngredientDetailView(ingredientName: ingredient, scan: scan)) {
                        SkinIngredientRow(
                            name: ingredient,
                            irritants: scan.skinPrediction?.irritants ?? [],
                            cautions: scan.skinPrediction?.cautions ?? []
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
                    showEditSheet = true
                } label: {
                    Label("Edit Ingredients", systemImage: "pencil")
                }
                Button {
                    sharePDF()
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
                Image(systemName: "ellipsis.circle").foregroundStyle(.white)
            }
        }
    }

    // MARK: - Reanalyze Banner

    private var reanalyzeBanner: some View {
        HStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Re-analysing with your current profile…")
                .font(.subheadline).foregroundStyle(.white)
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
        let vm = SkinViewModel(modelContext: modelContext, profileStore: profileStore)
        await vm.reanalyze(scan: scan)
        isReanalyzing = false
    }

    private func sharePDF() {
        let pdfData = generateSkinPDF()
        let activityVC = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
        activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact]
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    private func generateSkinPDF() -> Data {
        let pdfWidth: CGFloat = 612
        let pdfHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pdfWidth - (margin * 2)
        let pageBottom = pdfHeight - margin

        let ink      = UIColor(white: 0.10, alpha: 1)
        let subInk   = UIColor(white: 0.35, alpha: 1)
        let faintInk = UIColor(white: 0.55, alpha: 1)
        let divider  = UIColor(white: 0.85, alpha: 1)

        let skin = scan.skinPrediction
        let ratingColor: UIColor = {
            let r = skin?.rating.lowercased() ?? ""
            if r.contains("skin friendly")    { return UIColor(red: 0.18, green: 0.70, blue: 0.34, alpha: 1) }
            if r.contains("moderate concern") { return UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1) }
            if r.contains("high concern")     { return UIColor(red: 0.90, green: 0.23, blue: 0.23, alpha: 1) }
            return UIColor(white: 0.5, alpha: 1)
        }()

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight))

        return pdfRenderer.pdfData { ctx in
            var y: CGFloat = margin
            ctx.beginPage()

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageBottom { ctx.beginPage(); y = margin }
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
                divider.setStroke(); path.lineWidth = 0.5; path.stroke()
                y += 12
            }

            func drawSectionHeader(_ text: String) {
                ensureSpace(30); y += 8
                y += draw(text, x: margin, font: UIFont.boldSystemFont(ofSize: 11), color: faintInk) + 4
                drawDivider()
            }

            // Header
            y += draw("CheckMe", x: margin, font: UIFont.boldSystemFont(ofSize: 11), color: faintInk) + 2
            y += draw(scan.itemName, x: margin, font: UIFont.boldSystemFont(ofSize: 22), color: ink) + 2
            y += draw("Skincare · Scanned \(scan.dateSaved.shortDisplay)", x: margin, font: UIFont.systemFont(ofSize: 11), color: faintInk) + 4
            drawDivider(); y += 4

            // Rating pill
            if let skin {
                let ratingLabel = SkinRating(from: skin.rating).label
                let pillFont = UIFont.boldSystemFont(ofSize: 13)
                let pillAttrs: [NSAttributedString.Key: Any] = [.font: pillFont, .foregroundColor: UIColor.white]
                let pillSize = (ratingLabel as NSString).size(withAttributes: pillAttrs)
                let ph: CGFloat = 14, pv: CGFloat = 6
                let pillW = pillSize.width + ph * 2
                let pillH = pillSize.height + pv * 2
                ensureSpace(pillH + 10)
                let pillRect = CGRect(x: margin, y: y, width: pillW, height: pillH)
                UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2).fill()
                ratingColor.setFill()
                UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2).fill()
                (ratingLabel as NSString).draw(at: CGPoint(x: margin + ph, y: y + pv), withAttributes: pillAttrs)
                y += pillH + 10

                y += draw(skin.summary, x: margin, font: UIFont.systemFont(ofSize: 12), color: subInk) + 10

                if !skin.irritants.isEmpty {
                    y += draw("AVOID FOR YOUR SKIN", x: margin, font: UIFont.boldSystemFont(ofSize: 10), color: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)) + 4
                    y += draw(skin.irritants.map { "• \($0)" }.joined(separator: "\n"), x: margin + 8, font: UIFont.systemFont(ofSize: 11), color: subInk) + 8
                }
                if !skin.cautions.isEmpty {
                    y += draw("WATCH", x: margin, font: UIFont.boldSystemFont(ofSize: 10), color: UIColor(red: 0.80, green: 0.50, blue: 0.10, alpha: 1)) + 4
                    y += draw(skin.cautions.map { "• \($0)" }.joined(separator: "\n"), x: margin + 8, font: UIFont.systemFont(ofSize: 11), color: subInk) + 8
                }
                y += draw("TIP  \(skin.tip)", x: margin, font: UIFont.italicSystemFont(ofSize: 11), color: faintInk) + 8
            }

            // Ingredients
            drawSectionHeader("INGREDIENTS  (\(scan.ingredientCount))")
            let iFont = UIFont.systemFont(ofSize: 10)
            for (i, ingredient) in scan.ingredients.enumerated() {
                ensureSpace(15)
                y += draw("\(i + 1).  \(ingredient)", x: margin, font: iFont, color: subInk) + 3
            }

            // Footer
            ensureSpace(24); y = pageBottom - 8
            draw("Generated by CheckMe · \(scan.dateSaved.shortDisplay)", x: margin, font: UIFont.systemFont(ofSize: 9), color: faintInk)
        }
    }

    private func deleteScan() {
        dismiss()
        Task { @MainActor in
            modelContext.delete(scan)
            try? modelContext.save()
        }
    }

    // MARK: - Badge Sections

    private func irritantBadgesSection(_ irritants: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Avoid for your skin", systemImage: "xmark.octagon.fill")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.red.opacity(0.8))
            FlowLayout(spacing: 6) {
                ForEach(irritants, id: \.self) { irritant in
                    Text(irritant)
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
                .font(.caption).foregroundStyle(.yellow).lineLimit(1)
            Text(tip)
                .font(.caption).foregroundStyle(.white.opacity(0.7))
                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
    }
}

// MARK: - Ingredient Status

private enum SkinIngredientStatus {
    case safe
    case caution
    case irritant

    var color: Color {
        switch self { case .safe: .green; case .caution: .yellow; case .irritant: .red }
    }

    var icon: String {
        switch self { case .safe: "checkmark.circle.fill"; case .caution: "exclamationmark.triangle.fill"; case .irritant: "xmark.octagon.fill" }
    }

    var label: String {
        switch self { case .safe: "OK"; case .caution: "Watch"; case .irritant: "Avoid" }
    }
}

// MARK: - Ingredient Row

private struct SkinIngredientRow: View {
    let name: String
    let irritants: [String]
    let cautions: [String]

    private var status: SkinIngredientStatus {
        let lower = name.lowercased()
        if irritants.contains(where: { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }) {
            return .irritant
        }
        if cautions.contains(where: { $0.lowercased().contains(lower) || lower.contains($0.lowercased()) }) {
            return .caution
        }
        return .safe
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.icon)
                .font(.caption).foregroundStyle(status.color).frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline).foregroundStyle(.white)
                    .lineLimit(2).multilineTextAlignment(.leading)
                if status != .safe {
                    Text("Tap for details")
                        .font(.caption2).foregroundStyle(status.color.opacity(0.8))
                }
            }

            Spacer()

            if status != .safe {
                Text(status.label)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(status.color.opacity(0.12)))
            }

            Image(systemName: "info.circle.fill")
                .font(.caption2).foregroundStyle(status.color.opacity(0.6))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(
                status == .safe ? AnyShapeStyle(Color.white.opacity(0.05)) : AnyShapeStyle(status.color.opacity(0.07))
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(status == .safe ? Color.white.opacity(0.08) : status.color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Skin Rating Helper

struct SkinRating {
    let label: String
    let color: Color
    let icon: String

    init(from rating: String) {
        let lower = rating.lowercased()
        if lower.contains("skin friendly") {
            label = "Skin Friendly"; color = .green; icon = "leaf.fill"
        } else if lower.contains("moderate concern") {
            label = "Moderate Concern"; color = .orange; icon = "exclamationmark.triangle.fill"
        } else if lower.contains("high concern") {
            label = "High Concern"; color = .red; icon = "xmark.octagon.fill"
        } else {
            label = "Unknown"; color = .gray; icon = "questionmark.circle.fill"
        }
    }
}
