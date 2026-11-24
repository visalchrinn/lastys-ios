import ImageIO
import LastysCore
import PhotosUI
import SwiftUI
import UIKit
import Vision

/// Reads the QR codes in a photo. The reading is the only part that needs iOS; what to do with the
/// codes lives in `AppModel`, so the camera and a photo behave the same.
enum PhotoQRReader {
    /// The text of every QR in the image, in the order Vision found them. Empty if there is none.
    static func codes(in imageData: Data) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return [] }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).compactMap(\.payloadStringValue)
        }.value
    }
}

/// "Choose from Photos": the system photo picker, which needs no photo-library permission.
/// Reports the QR texts found in the picked photo, with the same success haptic as a camera read.
struct ChooseFromPhotosButton: View {
    let onCodes: ([String]) -> Void
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            Label("Choose from Photos", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(GhostButtonStyle())
        .onChange(of: item) { _, picked in
            guard let picked else { return }
            item = nil // so the same photo can be picked again
            Task {
                let data = try? await picked.loadTransferable(type: Data.self)
                var codes: [String] = []
                if let data { codes = await PhotoQRReader.codes(in: data) }
                if !codes.isEmpty { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                onCodes(codes)
            }
        }
    }
}

/// Says why a picked photo gave nothing to read. Shows nothing when there is no problem.
struct PhotoProblemLabel: View {
    let problem: PhotoProblem?

    var body: some View {
        if problem == .noQRFound {
            Label("No QR found in that photo. Try another, or use the camera.", systemImage: "qrcode.viewfinder")
                .font(.jakarta(14, .semibold))
                .foregroundStyle(Theme.roseDeep)
        }
    }
}

private extension CGImagePropertyOrientation {
    /// Vision wants the EXIF orientation, so a rotated photo still reads.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
