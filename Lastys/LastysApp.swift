import LastysCore
import SwiftUI

@main
struct LastysApp: App {
    @State private var launch = Launch.start()

    var body: some Scene {
        WindowGroup {
            Group {
                switch launch {
                case .ready(let model, let trustee):
                    AppRootView()
                        .environment(model)
                        .demoTrustee(trustee)
                case .failed(let message):
                    LaunchProblemView(message: message)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

/// Builds the app's state model from what this phone has saved.
enum Launch {
    case ready(AppModel, FakeTrustee)
    case failed(String)

    @MainActor static func start() -> Launch {
        let phoneKey: PhoneKey
        do {
            phoneKey = try PhoneKeyStore.loadOrCreate()
        } catch {
            return .failed("This iPhone couldn't create its Lastys key (\(error)).")
        }
        let folder = URL.applicationSupportDirectory.appending(path: "Lastys", directoryHint: .isDirectory)
        // Phase A: Trustee runs on the phone. Phase B swaps in the HTTP client.
        let trustee = FakeTrustee(savingTo: folder.appending(path: "trustee.json"))
        let model = AppModel(
            phoneKey: phoneKey,
            trustee: trustee.client(forPhone: phoneKey.trusteeID),
            store: FilePhoneStore(url: folder.appending(path: "phone.json")),
            connectivity: NetworkConnectivity(),
            moments: SampleData.moments()
        )
        return .ready(model, trustee)
    }
}

/// Onboarding until the person has a Lastys ID and a profile, then the tabs.
struct AppRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.screen {
            case .onboarding(let step):
                OnboardingView(step: step)
            case .home:
                RootView()
            }
        }
        .environment(\.locale, Locale(identifier: model.language.rawValue))
        .task(id: model.screen == .home) { await model.start() }
        // Phase A has no push: while a Relationship request waits, keep asking, wherever the person is in the app.
        .task(id: model.outgoingRequest?.status) {
            while model.outgoingRequest?.status == .pending, !Task.isCancelled {
                try? await Task.sleep(for: AppModel.pendingRequestCheckInterval)
                await model.refreshOutgoingRequest()
            }
        }
    }
}

struct LaunchProblemView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Wordmark()
            Text(message)
                .font(.jakarta(15))
                .foregroundStyle(Theme.ink)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
    }
}
