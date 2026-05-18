import SwiftUI
import SwiftData

// Full-screen camera view for scanning skincare/cosmetic labels.
// Mirrors CameraView.swift but uses SkinViewModel instead of IngredientsViewModel.

struct SkinCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self) private var themeManager

    let onScanComplete: (ScanModel) -> Void

    @State private var camera = Camera()
    @State private var viewModel: SkinViewModel?
    @State private var showFocusRing = false
    @State private var focusPoint: CGPoint = .zero
    @State private var capturedImageForPreview: UIImage?
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if let previewImage = capturedImageForPreview {
                photoPreviewScreen(previewImage)
            } else if camera.permissionGranted {
                GeometryReader { geo in
                    CameraPreview(session: camera.captureSession)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            let normalized = CGPoint(
                                x: location.x / geo.size.width,
                                y: location.y / geo.size.height
                            )
                            camera.focus(at: normalized)
                            focusPoint = location
                            withAnimation(.easeOut(duration: 0.2)) { showFocusRing = true }
                            withAnimation(.easeOut(duration: 0.4).delay(0.8)) { showFocusRing = false }
                        }

                    if showFocusRing {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.yellow, lineWidth: 1.5)
                            .frame(width: 64, height: 64)
                            .position(focusPoint)
                            .transition(.opacity.combined(with: .scale(scale: 1.3)))
                    }
                }
            } else if camera.permissionDenied {
                permissionDeniedView
            } else {
                Color.black.ignoresSafeArea()
            }

            if camera.permissionGranted && viewModel?.phase.isProcessing != true && capturedImageForPreview == nil {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .overlay(alignment: .topLeading) { topControls }
                        .ignoresSafeArea(edges: .top)

                    Spacer()
                    scanFrameHint
                    Spacer()

                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 200)
                        .overlay(alignment: .bottom) { bottomControls }
                        .ignoresSafeArea(edges: .bottom)
                }
            }

            if let vm = viewModel, vm.phase.isProcessing {
                processingOverlay(vm: vm)
            }

            if let vm = viewModel, vm.phase.isFailed {
                errorBanner(vm: vm)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            viewModel = SkinViewModel(modelContext: modelContext, profileStore: profileStore)
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: viewModel?.phase) { _, newPhase in
            guard let phase = newPhase else { return }
            if case .complete = phase, let scan = viewModel?.currentScan {
                onScanComplete(scan)
                dismiss()
                return
            }
            if phase.isProcessing {
                camera.stop()
            } else {
                camera.start()
            }
        }
    }

    // MARK: - Subviews

    private var topControls: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .padding(.leading, 16).padding(.top, 56)

            Spacer()

            Button { camera.toggleFlash() } label: {
                Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(camera.isFlashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .padding(.trailing, 16).padding(.top, 56)
        }
    }

    private var scanFrameHint: some View {
        CornerAccentsSkin()
            .stroke(.white.opacity(0.9), lineWidth: 3)
            .frame(width: 300, height: 180)
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            Text("Point at the ingredient list")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.85))

            Button { triggerCapture() } label: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.6), lineWidth: 3)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(.white)
                        .frame(width: 62, height: 62)
                }
            }
            .disabled(viewModel?.phase.isProcessing ?? false)
        }
        .padding(.bottom, 48)
    }

    private func processingOverlay(vm: SkinViewModel) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)

                VStack(spacing: 8) {
                    Text(vm.phase.statusText)
                        .font(.headline).fontWeight(.semibold)
                        .foregroundStyle(.white)

                    if !vm.partialProductName.isEmpty {
                        Text(vm.partialProductName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if !vm.partialIngredients.isEmpty {
                        Text("\(vm.partialIngredients.count) ingredients found")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(32)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: vm.phase)
    }

    private func errorBanner(vm: SkinViewModel) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan failed")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if case .failed(let msg) = vm.phase {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button("Retry") { vm.reset() }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
            .padding()
            .background(.ultraThinMaterial.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: vm.phase)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.4))
            Text("Camera Access Required")
                .font(.title2).fontWeight(.bold).foregroundStyle(.white)
            Text("CheckMe needs camera access to scan ingredient labels.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Actions

    private func triggerCapture() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        Task {
            do {
                let image = try await camera.capturePhoto()
                await MainActor.run { capturedImageForPreview = image }
            } catch {
                await MainActor.run { viewModel?.phase = .failed(error.localizedDescription) }
            }
        }
    }

    private func photoPreviewScreen(_ image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.4)))
                    }
                    Spacer()
                    Button { zoomScale = min(zoomScale + 0.2, 3.0) } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title3).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.4)))
                    }
                    Button { zoomScale = max(zoomScale - 0.2, 1.0) } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title3).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.4)))
                    }
                }
                .padding(16)

                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale)
                    .clipped()
                    .padding(20)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        capturedImageForPreview = nil
                        zoomScale = 1.0
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white.opacity(0.2)))
                    }

                    Button {
                        guard let vm = viewModel else { return }
                        capturedImageForPreview = nil
                        Task { await vm.processCapture(image) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("Analyze")
                        }
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Corner Accents Shape (skin camera)

private struct CornerAccentsSkin: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 16
        let len: CGFloat = 28

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + r + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r + len, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - r - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r + len))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - r - len))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - r - len, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + r + len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r - len))

        return path
    }
}
