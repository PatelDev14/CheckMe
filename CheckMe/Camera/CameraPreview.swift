import SwiftUI
import AVFoundation

// UIViewRepresentable that hosts AVCaptureVideoPreviewLayer.
// Using a UIView subclass lets us override layerClass, which is the
// only way to make a preview layer that resizes correctly with Auto Layout.

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Session reference is stable — nothing to update after creation
    }

    // MARK: - Subclass

    final class PreviewView: UIView {
        // Returning AVCaptureVideoPreviewLayer here makes UIKit use it as the
        // backing layer, giving us GPU compositing for free instead of drawing
        // the camera feed into a secondary layer.
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // Safe force-cast: layerClass guarantees this type
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
