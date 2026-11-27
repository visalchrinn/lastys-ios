import AVFoundation
import ImageIO
import LastysCore
import SwiftUI
import UIKit

/// A Moment's first photo, or its video's first frame with a play mark, sized for a list.
/// Decorative: the row around it says what the Moment is.
struct MomentThumbnail: View {
    let media: MomentMedia
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 12

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.roseTint
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
            } else {
                Image(systemName: media.kind == .video ? "video.fill" : "photo.fill")
                    .foregroundStyle(Theme.rose)
            }
            if media.kind == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: min(width, height) * 0.2, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: min(width, height) * 0.42, height: min(width, height) * 0.42)
                    .background(Circle().fill(Theme.ink.opacity(0.55)))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
        .task(id: media) {
            image = await MomentThumbnails.image(for: media, maxPixelSize: max(width, height) * displayScale)
        }
    }
}

/// Small, cached images of Moment media, so Home never decodes a full-size photo per row.
@MainActor
enum MomentThumbnails {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for media: MomentMedia, maxPixelSize: CGFloat) async -> UIImage? {
        let key = "\(media.fileName)@\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url = MomentMediaFiles.url(for: media)
        let made: UIImage?
        switch media.kind {
        case .photo:
            made = await Task.detached(priority: .utility) { downsampledPhoto(at: url, maxPixelSize: maxPixelSize) }.value
        case .video:
            made = await firstFrame(of: url, maxPixelSize: maxPixelSize)
        }
        if let made { cache.setObject(made, forKey: key) }
        return made
    }

    /// Decodes only as many pixels as the thumbnail needs, upright.
    nonisolated private static func downsampledPhoto(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func firstFrame(of url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        guard let frame = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: frame.image)
    }
}
