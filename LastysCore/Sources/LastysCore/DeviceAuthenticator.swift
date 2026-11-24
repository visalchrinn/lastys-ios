/// Face ID, Touch ID or the passcode: proves the phone's owner is holding it before anything sensitive
/// shows, such as the Recovery code.
public protocol DeviceAuthenticator: Sendable {
    func authenticate(reason: String) async -> Bool
}
