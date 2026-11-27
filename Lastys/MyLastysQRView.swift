import CoreImage.CIFilterBuiltins
import LastysCore
import SwiftUI

/// My Lastys QR: made on the phone with no network, and the same until its owner revokes it for a new one.
struct MyLastysQRView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingRevoke = false
    @State private var inviting = false
    #if DEBUG
    @Environment(\.demoTrustee) private var demoTrustee
    #else
    private let demoTrustee: FakeTrustee? = nil
    #endif

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

            if let qr = model.myLastysQR() {
                QRCodeImage(payload: qr.payload)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.cardBorder, lineWidth: 1)
                    )
                    .accessibilityLabel(Text("My Lastys QR"))
                    .id(model.qrRevokedCount)
                    .transition(.opacity)
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

            VStack(spacing: 10) {
                Button {
                    confirmingRevoke = true
                } label: {
                    HStack(spacing: 8) {
                        if model.isRevokingQR { ProgressView() }
                        Label("Revoke and get a new QR", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(model.isRevokingQR)

                if let problem = model.qrProblem {
                    Text(problem == .needsInternet
                        ? LocalizedStringKey("Revoking needs an internet connection. Your current QR still works.")
                        : LocalizedStringKey("Couldn't reach Lastys. Your current QR still works. Try again."))
                        .font(.jakarta(13, .medium))
                        .foregroundStyle(Theme.roseDeep)
                        .multilineTextAlignment(.center)
                }

                Text("Your QR stays the same until you revoke it, and works without internet. If someone has a screenshot of it, revoke it: the old QR stops working at once.")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                if model.canInvite {
                    Button("Partner not on Lastys yet? Send an invite link") { inviting = true }
                        .font(.jakarta(14, .semibold))
                        .underline()
                        .foregroundStyle(Theme.roseDark)
                        .frame(minHeight: 44)
                }
            }

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: model.qrRevokedCount)
        .confirmationDialog("Revoke this QR?", isPresented: $confirmingRevoke, titleVisibility: .visible) {
            Button("Revoke and get a new QR", role: .destructive) {
                Task { await model.revokeMyLastysQR() }
            }
        } message: {
            Text("The QR you are showing now, and any screenshot or shared card that has it, will stop working. Share the new one instead.")
        }
        .sheet(isPresented: $inviting) {
            InvitePartnerSheet()
                .environment(model)
                .demoTrustee(demoTrustee)
                .presentationDragIndicator(.visible)
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
