import SwiftUI

// Full-screen image crop UI shown between photo capture and analysis.
// Four corner handles let the user isolate the relevant label area (e.g. just
// the English block on a bilingual label, or just the nutrition panel on a busy package).
// Produces a UIImage cropped to the selected rect, respecting image orientation.

struct ImageCropView: View {
    let image: UIImage
    let tintColor: Color
    let onCrop: (UIImage) -> Void   // user confirmed crop
    let onUseFull: () -> Void        // skip crop, use original
    let onRetake: () -> Void         // go back to camera

    // Crop edges in view (image-display) coordinates
    @State private var left:   CGFloat = 0
    @State private var right:  CGFloat = 0
    @State private var top:    CGFloat = 0
    @State private var bottom: CGFloat = 0
    @State private var imageRect: CGRect = .zero
    @State private var ready = false

    // Per-handle previous drag translation (delta approach — avoids GestureState complexity)
    @State private var tlPrev = CGSize.zero
    @State private var trPrev = CGSize.zero
    @State private var blPrev = CGSize.zero
    @State private var brPrev = CGSize.zero

    private let minCrop: CGFloat = 50
    private let handleRadius: CGFloat = 12

    var cropRect: CGRect {
        CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if ready {
                    dimOverlay(size: geo.size)
                    cropBorder
                    gridLines
                    cornerHandles
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: .bottom) { bottomBar }
            .onAppear { setup(in: geo.size) }
        }
        .ignoresSafeArea()
    }

    // MARK: - Setup

    private func setup(in size: CGSize) {
        let imgRect = computeImageRect(in: size)
        imageRect = imgRect
        let inset = CGFloat(0.08)
        left   = imgRect.minX + imgRect.width  * inset
        right  = imgRect.maxX - imgRect.width  * inset
        top    = imgRect.minY + imgRect.height * inset
        bottom = imgRect.maxY - imgRect.height * inset
        ready  = true
    }

    private func computeImageRect(in size: CGSize) -> CGRect {
        let imgAspect  = image.size.width / image.size.height
        let viewAspect = size.width / size.height
        if imgAspect > viewAspect {
            let h = size.width / imgAspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        } else {
            let w = size.height * imgAspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        }
    }

    // MARK: - Overlay views

    private func dimOverlay(size: CGSize) -> some View {
        Path { p in
            p.addRect(CGRect(origin: .zero, size: size))
            p.addRect(cropRect)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var cropBorder: some View {
        Rectangle()
            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            .allowsHitTesting(false)
    }

    private var gridLines: some View {
        let cw = cropRect.width / 3
        let ch = cropRect.height / 3
        return ZStack {
            // Vertical thirds
            Rectangle().fill(Color.white.opacity(0.22)).frame(width: 0.5, height: cropRect.height)
                .position(x: cropRect.minX + cw, y: cropRect.midY)
            Rectangle().fill(Color.white.opacity(0.22)).frame(width: 0.5, height: cropRect.height)
                .position(x: cropRect.minX + cw * 2, y: cropRect.midY)
            // Horizontal thirds
            Rectangle().fill(Color.white.opacity(0.22)).frame(width: cropRect.width, height: 0.5)
                .position(x: cropRect.midX, y: cropRect.minY + ch)
            Rectangle().fill(Color.white.opacity(0.22)).frame(width: cropRect.width, height: 0.5)
                .position(x: cropRect.midX, y: cropRect.minY + ch * 2)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Corner Handles

    private var cornerHandles: some View {
        ZStack {
            // Top-left
            cornerHandle(pos: CGPoint(x: left, y: top))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dx = v.translation.width  - tlPrev.width
                        let dy = v.translation.height - tlPrev.height
                        tlPrev = v.translation
                        left  = clamp(left  + dx, lo: imageRect.minX, hi: right  - minCrop)
                        top   = clamp(top   + dy, lo: imageRect.minY, hi: bottom - minCrop)
                    }
                    .onEnded { _ in tlPrev = .zero }
                )

            // Top-right
            cornerHandle(pos: CGPoint(x: right, y: top))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dx = v.translation.width  - trPrev.width
                        let dy = v.translation.height - trPrev.height
                        trPrev = v.translation
                        right = clamp(right + dx, lo: left   + minCrop, hi: imageRect.maxX)
                        top   = clamp(top   + dy, lo: imageRect.minY,   hi: bottom - minCrop)
                    }
                    .onEnded { _ in trPrev = .zero }
                )

            // Bottom-left
            cornerHandle(pos: CGPoint(x: left, y: bottom))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dx = v.translation.width  - blPrev.width
                        let dy = v.translation.height - blPrev.height
                        blPrev = v.translation
                        left   = clamp(left   + dx, lo: imageRect.minX, hi: right  - minCrop)
                        bottom = clamp(bottom + dy, lo: top + minCrop,   hi: imageRect.maxY)
                    }
                    .onEnded { _ in blPrev = .zero }
                )

            // Bottom-right
            cornerHandle(pos: CGPoint(x: right, y: bottom))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dx = v.translation.width  - brPrev.width
                        let dy = v.translation.height - brPrev.height
                        brPrev = v.translation
                        right  = clamp(right  + dx, lo: left + minCrop,  hi: imageRect.maxX)
                        bottom = clamp(bottom + dy, lo: top  + minCrop,  hi: imageRect.maxY)
                    }
                    .onEnded { _ in brPrev = .zero }
                )
        }
    }

    private func cornerHandle(pos: CGPoint) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleRadius * 2, height: handleRadius * 2)
            .shadow(color: .black.opacity(0.35), radius: 4)
            .contentShape(Circle().scale(2.5))  // large touch target
            .position(pos)
    }

    // MARK: - Bars

    private var topBar: some View {
        HStack {
            Button { onRetake() } label: {
                Image(systemName: "xmark")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            Spacer()
            Text("Crop Image")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            Spacer()
            // Balance the X button
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                onUseFull()
            } label: {
                Text("Use Full")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(.white.opacity(0.15)))
            }

            Button {
                performCrop()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crop")
                    Text("Crop & Scan")
                }
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(tintColor))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
    }

    // MARK: - Crop Execution

    private func performCrop() {
        guard imageRect.width > 0, imageRect.height > 0 else { onUseFull(); return }

        let normalizedImg = normalized(image)
        guard let cgImage = normalizedImg.cgImage else { onUseFull(); return }

        // cgImage.cropping(to:) uses PIXEL coordinates, not UIImage point coordinates.
        // A 3× retina camera image has cgImage.width = 3 × normalizedImg.size.width.
        // Using size.width here was the regression bug: it made the crop rect 9× too
        // small (3× in each axis), producing a tiny blurry fragment that Vision fails on.
        let scaleX = CGFloat(cgImage.width)  / imageRect.width
        let scaleY = CGFloat(cgImage.height) / imageRect.height

        let pixelBounds = CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height))
        let pixelRect = CGRect(
            x: (cropRect.minX - imageRect.minX) * scaleX,
            y: (cropRect.minY - imageRect.minY) * scaleY,
            width:  cropRect.width  * scaleX,
            height: cropRect.height * scaleY
        ).intersection(pixelBounds)

        guard !pixelRect.isNull, !pixelRect.isEmpty,
              let cropped = cgImage.cropping(to: pixelRect) else {
            onUseFull()
            return
        }
        onCrop(UIImage(cgImage: cropped))
    }

    // Render image into an upright UIGraphicsContext to strip EXIF orientation.
    private func normalized(_ img: UIImage) -> UIImage {
        guard img.imageOrientation != .up else { return img }
        let renderer = UIGraphicsImageRenderer(size: img.size)
        return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: img.size)) }
    }

    private func clamp(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }
}
