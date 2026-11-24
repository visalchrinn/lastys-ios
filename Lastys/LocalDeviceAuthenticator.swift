import Foundation
import LastysCore
import LocalAuthentication

/// Face ID, Touch ID or, failing those, the device passcode.
struct LocalDeviceAuthenticator: DeviceAuthenticator {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: AppText.lookup(reason))) ?? false
    }
}

/// Always says yes, for SwiftUI previews.
struct PreviewAuthenticator: DeviceAuthenticator {
    func authenticate(reason: String) async -> Bool { true }
}
