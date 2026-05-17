import AVFoundation
import UIKit

// Manages the AVCaptureSession lifecycle, flash, tap-to-focus, and photo capture.
// Runs session configuration on a dedicated background queue; all observable
// state changes are dispatched back to the MainActor for SwiftUI.

@Observable
@MainActor
final class Camera: NSObject {

    // MARK: - Observable State

    var capturedImage: UIImage?
    var isSessionRunning = false
    var isFlashOn = false
    var permissionGranted = false
    var permissionDenied = false

    // MARK: - Private

    private let session = AVCaptureSession()
    // Session start/stop and configuration must happen off the main thread
    private let sessionQueue = DispatchQueue(label: "com.checkme.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?

    // Bridges async/await caller (capturePhoto) with the delegate callback
    // Only one concurrent capture allowed — guards against multiple taps
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var isCaptureInFlight = false

    // MARK: - Init

    override init() {
        super.init()
        requestPermission()
    }

    // MARK: - Permission

    private func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            sessionQueue.async { self.configureSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.permissionGranted = granted
                    self.permissionDenied = !granted
                    if granted { self.sessionQueue.async { self.configureSession() } }
                }
            }
        default:
            permissionDenied = true
        }
    }

    // MARK: - Session Configuration

    // Called only on sessionQueue — never call from MainActor directly
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        // .photo preset already captures at max sensor resolution; no extra flag needed

        // Keep a strong reference so focus/exposure changes work later
        let cap = device
        session.commitConfiguration()
        Task { @MainActor in self.currentDevice = cap }
    }

    // MARK: - Session Lifecycle

    func start() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in self.isSessionRunning = true }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in self.isSessionRunning = false }
        }
    }

    /// The underlying session passed to CameraPreview for the preview layer
    var captureSession: AVCaptureSession { session }

    // MARK: - Flash

    func toggleFlash() {
        isFlashOn.toggle()
    }

    // MARK: - Tap-to-Focus

    /// Call with the tap location as a fraction of the preview view size (0–1).
    /// Converts to AVFoundation device coordinates (also 0–1, rotated 90° for portrait).
    func focus(at normalizedPoint: CGPoint) {
        guard let device = currentDevice, device.isFocusPointOfInterestSupported else { return }
        // In portrait, AVFoundation device coords are: x = screen-y, y = 1 - screen-x
        let devicePoint = CGPoint(x: normalizedPoint.y, y: 1.0 - normalizedPoint.x)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    // MARK: - Capture

    /// Captures a still photo and returns it as UIImage.
    /// Suspends the caller until the delegate fires.
    /// Guards against multiple concurrent captures and checks session state.
    func capturePhoto() async throws -> UIImage {
        // Prevent multiple concurrent captures
        guard !isCaptureInFlight else {
            throw CameraError.captureAlreadyInProgress
        }

        // Ensure session is running
        guard isSessionRunning else {
            throw CameraError.sessionNotRunning
        }

        return try await withCheckedThrowingContinuation { continuation in
            isCaptureInFlight = true
            photoContinuation = continuation

            var settings = AVCapturePhotoSettings()
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            settings.flashMode = isFlashOn ? .on : .off

            // Capture on the session queue to avoid race conditions
            sessionQueue.async {
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension Camera: AVCapturePhotoCaptureDelegate {
    // Called on an arbitrary background queue — must not touch @MainActor state directly
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // Always dispatch back to MainActor to safely access continuation and isCaptureInFlight
        Task { @MainActor [weak self] in
            defer {
                self?.photoContinuation = nil
                self?.isCaptureInFlight = false
            }

            guard let continuation = self?.photoContinuation else { return }

            if let error {
                continuation.resume(throwing: error)
                return
            }

            guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
                continuation.resume(throwing: CameraError.captureFailure)
                return
            }

            self?.capturedImage = image
            continuation.resume(returning: image)
        }
    }
}

// MARK: - Error

enum CameraError: LocalizedError {
    case captureFailure
    case sessionNotRunning
    case captureAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .captureFailure:           return "Could not capture photo. Please try again."
        case .sessionNotRunning:        return "Camera is not ready. Try closing and reopening the camera."
        case .captureAlreadyInProgress: return "Capture is already in progress. Wait for it to complete."
        }
    }
}
