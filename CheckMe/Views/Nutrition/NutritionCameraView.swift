import SwiftUI
import SwiftData
import PhotosUI

// Full-screen camera for scanning a Nutrition Facts panel.
// Mirrors SkinCameraView but uses NutritionViewModel.

struct NutritionCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(ThemeManager.self) private var themeManager

    let onScanComplete: (ScanModel) -> Void

    @State private var camera = Camera()
    @State private var viewModel: NutritionViewModel?
    @State private var showFocusRing = false
    @State private var focusPoint: CGPoint = .zero
    @State private var capturedImageForPreview: UIImage?
    @State private var zoomScale: CGFloat = 1.0
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            if let previewImage = capturedImageForPreview {
                cropScreen(previewImage)
            } else if camera.permissionGranted {
                GeometryReader { geo in
                    CameraPreview(session: camera.captureSession)
                        .ignoresSafeArea()
                        .onTapGesture { location in
                            let normalized = CGPoint(x: location.x / geo.size.width, y: location.y / geo.size.height)
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

                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea(edges: .bottom)
                        bottomControls
                    }
                    .frame(maxWidth: .infinity)
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
            viewModel = NutritionViewModel(modelContext: modelContext, profileStore: profileStore)
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: viewModel?.phase) { _, newPhase in
            guard let phase = newPhase else { return }
            // Navigate away on success
            if case .complete = phase, let scan = viewModel?.currentScan {
                onScanComplete(scan)
                dismiss()
                return
            }
            // Stop the camera session while AI is running — the Neural Engine is shared
            // between AVFoundation and FoundationModels. Keeping the camera running during
            // processing causes resource contention that makes retry attempts fail even with
            // a clean image. Stopping frees the Neural Engine for the AI pipeline.
            if phase.isProcessing {
                camera.stop()
            } else {
                // idle (fresh start or after vm.reset()), failed (show error, ready to retry)
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
        // Wider frame for nutrition panels which are typically taller than ingredient lists
        CornerAccentsNutrition()
            .stroke(.white.opacity(0.9), lineWidth: 3)
            .frame(width: 280, height: 220)
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            Text("Point at the Nutrition Facts panel")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.85))

            HStack {
                // Photo library picker — left of shutter
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(.black.opacity(0.4)))
                }
                .onChange(of: selectedPhoto) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run { capturedImageForPreview = image }
                        }
                        await MainActor.run { selectedPhoto = nil }
                    }
                }

                Spacer()

                Button { triggerCapture() } label: {
                    ZStack {
                        Circle().stroke(.white.opacity(0.6), lineWidth: 3).frame(width: 78, height: 78)
                        Circle().fill(.white).frame(width: 62, height: 62)
                    }
                }
                .disabled(viewModel?.phase.isProcessing ?? false)

                Spacer()

                // Balancing spacer so shutter stays centred
                Color.clear.frame(width: 54, height: 54)
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 48)
    }

    private func processingOverlay(vm: NutritionViewModel) -> some View {
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
                }
            }
            .padding(32)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: vm.phase)
    }

    private func errorBanner(vm: NutritionViewModel) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan failed")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                    if case .failed(let msg) = vm.phase {
                        Text(msg).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
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
            Image(systemName: "camera.fill").font(.system(size: 56)).foregroundStyle(.white.opacity(0.4))
            Text("Camera Access Required").font(.title2).fontWeight(.bold).foregroundStyle(.white)
            Text("CheckMe needs camera access to scan nutrition labels.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32).background(Color.black.ignoresSafeArea())
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

    private func cropScreen(_ image: UIImage) -> some View {
        ImageCropView(
            image: image,
            tintColor: Color(red: 0.55, green: 0.45, blue: 0.95),
            onCrop: { cropped in
                guard let vm = viewModel else { return }
                capturedImageForPreview = nil
                Task { await vm.processCapture(cropped) }
            },
            onUseFull: {
                guard let vm = viewModel else { return }
                capturedImageForPreview = nil
                Task { await vm.processCapture(image) }
            },
            onRetake: {
                capturedImageForPreview = nil
                zoomScale = 1.0
            }
        )
    }
}

// MARK: - Corner Accents Shape

private struct CornerAccentsNutrition: Shape {
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
