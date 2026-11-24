// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LastysCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LastysCore", targets: ["LastysCore"]),
    ],
    dependencies: [
        // CryptoKit's API on every platform; on Apple platforms it re-exports CryptoKit itself.
        .package(url: "https://github.com/apple/swift-crypto.git", "5.1.0"..<"6.0.0"),
    ],
    targets: [
        .target(name: "LastysCore", dependencies: [.product(name: "Crypto", package: "swift-crypto")]),
        // Runs the shared scenarios in /scenarios against a TrusteeClient. Test-only; the app never links it.
        .target(name: "LastysScenarios", dependencies: ["LastysCore"]),
        .testTarget(name: "LastysCoreTests", dependencies: ["LastysCore", "LastysScenarios"]),
    ]
)
