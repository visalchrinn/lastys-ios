import AVFoundation
import LastysCore
import SwiftUI
import UIKit

/// "Scan a QR": the camera, then the Scan result live from Trustee, then any Relationship request.
struct ScanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var showsOutcome: Bool {
        model.isScanning || model.scanResult != nil || model.scanProblem != nil
    }

    private var title: LocalizedStringKey {
        if model.outgoingRequest != nil { return "Relationship request" }
        return showsOutcome ? "Scan result" : "Scan a Lastys QR"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.jakarta(22, .heavy))
                    .tracking(-0.4)
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            if let request = model.outgoingRequest {
                RelationshipRequestStatusView(request: request, done: close)
            } else if showsOutcome {
                ScanOutcomeView()
            } else {
                ScannerStep()
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.background.ignoresSafeArea())
    }

    private func close() {
        model.dismissOutgoingRequest()
        model.clearScan()
        dismiss()
    }
}

// MARK: Scanning

private struct ScannerStep: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var torchOn = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                camera
                    .frame(height: 340)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                ChooseFromPhotosButton { codes in
                    Task { await model.scan(photoCodes: codes) }
                }

                if model.photoProblem == .noQRFound {
                    Label("No QR found in that photo. Try another, or use the camera.", systemImage: "qrcode.viewfinder")
                        .font(.jakarta(14, .semibold))
                        .foregroundStyle(Theme.roseDeep)
                }

                Text("Point the camera at someone's Lastys QR, or choose a photo of it. Their status comes live from Lastys.")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)

                #if DEBUG
                DemoPeoplePicker()
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .task {
            if access == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                access = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    @ViewBuilder
    private var camera: some View {
        switch access {
        case .authorized where AVCaptureDevice.default(for: .video) != nil:
            CameraQRScanner(torchOn: torchOn) { payload in
                Task { await model.scan(payload) }
            }
            .overlay(alignment: .bottomTrailing) {
                if AVCaptureDevice.default(for: .video)?.hasTorch == true {
                    Button {
                        torchOn.toggle()
                    } label: {
                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .accessibilityLabel(Text(torchOn ? "Turn torch off" : "Turn torch on"))
                    .padding(12)
                }
            }
        case .authorized:
            cameraMessage("This device has no camera.")
        case .notDetermined:
            Theme.ink
        default:
            VStack(spacing: 12) {
                cameraMessage("Lastys needs the camera to Scan. Allow it in Settings.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ink)
        }
    }

    private func cameraMessage(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.jakarta(15, .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ink)
    }
}

#if DEBUG
/// Demo: Scan a sample person without a second phone. Compiled only in Debug.
private struct DemoPeoplePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.demoTrustee) private var trustee

    var body: some View {
        if let trustee {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: "Demo: pick a QR to scan")
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(Theme.muted)
                ForEach(DemoPerson.allCases, id: \.self) { person in
                    Button {
                        Task {
                            guard let payload = try? await trustee.demoLastysQR(of: person, at: Date()) else { return }
                            await model.scan(payload)
                        }
                    } label: {
                        HStack {
                            Text(verbatim: person.nickname).font(.jakarta(15, .bold))
                            Spacer()
                            Text(verbatim: person.demoDescription)
                                .font(.jakarta(13))
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }
}

private extension DemoPerson {
    var demoDescription: String {
        switch self {
        case .dara: return "Single, shares history"
        case .vanna: return "Brand-new ID, Status only"
        case .sokha: return "Taken"
        }
    }
}
#endif

// MARK: Outcome

private struct ScanOutcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if model.isScanning {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let result = model.scanResult {
                    ScanResultCard(result: result)
                    RelationshipRequestButton(result: result)
                } else if let problem = model.scanProblem {
                    ScanProblemCard(problem: problem)
                }
                if !model.isScanning {
                    Button("Scan again") { model.clearScan() }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

private struct ScanResultCard: View {
    let result: ScanResult

    private static let month: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: result.nickname)
                        .font(.jakarta(22, .heavy))
                    statusBadge
                }
                Spacer(minLength: 0)
            }
            .card()

            if result.isVeryNew {
                Label("This Lastys ID is very new. If you're getting serious, talk openly about whether either of you has another one.", systemImage: "exclamationmark.triangle")
                    .font(.jakarta(14, .medium))
                    .foregroundStyle(Theme.roseDeep)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))
            }

            VStack(alignment: .leading, spacing: 12) {
                fact("ID age", value: Text("\(result.idAgeDays) days"))
                Divider().overlay(Theme.divider)
                fact("Phone transfers", value: Text("\(result.phoneTransferCount)"))
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Text("Relationship history")
                    .font(.jakarta(15, .bold))
                if let history = result.relationshipHistory {
                    if history.isEmpty {
                        Text("No past relationships")
                            .font(.jakarta(14))
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("\(history.count) past relationships")
                            .font(.jakarta(14))
                            .foregroundStyle(Theme.muted)
                        ForEach(history, id: \.self) { past in
                            Text(verbatim: "\(Self.monthText(past.started)) – \(Self.monthText(past.ended))")
                                .font(.jakarta(14, .semibold))
                        }
                    }
                } else {
                    Label("Hidden by owner", systemImage: "eye.slash")
                        .font(.jakarta(14))
                        .foregroundStyle(Theme.muted)
                }
            }
            .card()
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = result.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
        } else {
            Text(String(result.nickname.prefix(1)).uppercased())
                .font(.jakarta(24, .heavy))
                .foregroundStyle(Theme.roseDark)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.roseTint))
        }
    }

    private var statusBadge: some View {
        let single = result.status == .single
        return Label(single ? LocalizedStringKey("Verified Single") : LocalizedStringKey("Taken"), systemImage: single ? "checkmark.shield" : "heart.fill")
            .font(.jakarta(13, .bold))
            .foregroundStyle(single ? Theme.green : Theme.roseDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(single ? Theme.greenTint : Theme.roseTint))
    }

    private func fact(_ title: LocalizedStringKey, value: Text) -> some View {
        HStack {
            Text(title).font(.jakarta(14)).foregroundStyle(Theme.muted)
            Spacer()
            value.font(.jakarta(15, .bold))
        }
    }

    private static func monthText(_ month: YearMonth) -> String {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: month.year, month: month.month)) ?? Date()
        return Self.month.string(from: date)
    }
}

private struct ScanProblemCard: View {
    let problem: ScanProblem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.rose)
                .accessibilityHidden(true)
            Text(message)
                .font(.jakarta(16, .semibold))
        }
        .card(padding: 20)
    }

    private var icon: String {
        switch problem {
        case .needsInternet: return "wifi.slash"
        case .expiredQR: return "clock.badge.exclamationmark"
        case .forgedQR: return "exclamationmark.shield"
        case .notALastysQR, .noLastysID: return "qrcode"
        case .couldNotReachLastys: return "exclamationmark.icloud"
        }
    }

    private var message: LocalizedStringKey {
        switch problem {
        case .needsInternet:
            return "A Scan needs an internet connection, so you always see their status as it is right now."
        case .expiredQR:
            return "This Lastys QR has expired. It may be a screenshot. Ask them to show their QR again."
        case .forgedQR:
            return "This isn't a genuine Lastys QR. Don't trust what it claims."
        case .notALastysQR:
            return "That's not a Lastys QR."
        case .noLastysID:
            return "You need your own Lastys ID to Scan."
        case .couldNotReachLastys:
            return "Couldn't check with Lastys right now. Try again."
        }
    }
}

// MARK: Camera

/// The camera, reading QR codes. Reports each code once until the view is rebuilt.
struct CameraQRScanner: UIViewControllerRepresentable {
    let torchOn: Bool
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: QRScannerController, context: Context) {
        controller.onCode = onCode
        controller.setTorch(on: torchOn)
    }
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.lastys.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasReported = false
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTorch(on: false)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (device.torchMode == .on) != on,
              (try? device.lockForConfiguration()) != nil
        else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasReported,
              let code = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first?.stringValue
        else { return }
        hasReported = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCode?(code)
    }
}

#Preview {
    ScanView()
        .environment(AppModel.preview())
}
