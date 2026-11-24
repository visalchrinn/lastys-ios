import CoreImage.CIFilterBuiltins
import LastysCore
import SwiftUI

/// My Lastys QR: a new code every minute with a countdown, made on the phone with no network.
struct MyLastysQRView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("My Lastys QR")
                    .font(.jakarta(22, .heavy))
                    .tracking(-0.4)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }

            // Ticks on whole seconds from the start of the minute, so the code changes right at the boundary.
            TimelineView(.periodic(from: LastysQRToken.startOfMinute(containing: .now), by: 1)) { context in
                if let qr = model.myLastysQR(at: context.date) {
                    VStack(spacing: 16) {
                        QRCodeImage(payload: qr.payload)
                            .frame(maxWidth: 280, maxHeight: 280)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
                            )
                            .accessibilityLabel(Text("My Lastys QR"))

                        HStack(spacing: 10) {
                            ProgressView(value: Double(qr.secondsUntilNextCode), total: Double(LastysQRToken.secondsPerCode))
                                .tint(Theme.rose)
                            Text("New code in \(qr.secondsUntilNextCode)s")
                                .font(.jakarta(13, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
            }

            if let personalID = model.lastysID?.personalID {
                Text(verbatim: personalID)
                    .font(.jakarta(15, .bold))
                    .tracking(0.5)
            }

            HStack(spacing: 12) {
                Image(systemName: "eye")
                    .foregroundStyle(Theme.rose)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanners will see")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                    Text(model.shareLevel.title)
                        .font(.jakarta(15, .bold))
                }
                Spacer(minLength: 0)
            }
            .card()

            Text("Works without internet. Each code is good for a minute, so a screenshot can't be reused.")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
    }
}

extension ShareLevel {
    var title: LocalizedStringKey {
        switch self {
        case .statusOnly: return "Status only"
        case .statusAndHistory: return "Status + history"
        }
    }
}

/// A crisp QR for `payload`, scaled without smoothing.
struct QRCodeImage: View {
    let payload: String

    var body: some View {
        if let image = Self.render(payload) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }

    private static let context = CIContext()

    private static func render(_ payload: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return context.createCGImage(output, from: output.extent)
    }
}

#Preview {
    MyLastysQRView()
        .environment(AppModel.preview())
}
