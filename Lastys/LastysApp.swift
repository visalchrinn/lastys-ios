import LastysCore
import SwiftUI

@main
struct LastysApp: App {
    /// Phase A: Trustee runs on the phone. Phase B swaps in the HTTP client.
    private static let trustee = FakeTrustee()

    @State private var model = AppModel.sample(trustee: LastysApp.trustee.client(forPhone: "this-phone"))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.start() }
                .preferredColorScheme(.light)
        }
    }
}
