import LastysCore
import SwiftUI

#if DEBUG
private struct DemoTrusteeKey: EnvironmentKey {
    static let defaultValue: FakeTrustee? = nil
}

extension EnvironmentValues {
    /// Debug only: the fake Trustee, for "Demo: …" controls.
    var demoTrustee: FakeTrustee? {
        get { self[DemoTrusteeKey.self] }
        set { self[DemoTrusteeKey.self] = newValue }
    }
}
#endif

extension View {
    /// Debug: hands the fake Trustee to the "Demo: …" controls below. Release: does nothing.
    func demoTrustee(_ trustee: FakeTrustee?) -> some View {
        #if DEBUG
        return environment(\.demoTrustee, trustee)
        #else
        return self
        #endif
    }
}
