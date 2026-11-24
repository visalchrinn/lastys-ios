// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LastysCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LastysCore", targets: ["LastysCore"]),
    ],
    targets: [
        .target(name: "LastysCore"),
        // Runs the shared scenarios in /scenarios against a TrusteeClient. Test-only; the app never links it.
        .target(name: "LastysScenarios", dependencies: ["LastysCore"]),
        .testTarget(name: "LastysCoreTests", dependencies: ["LastysCore", "LastysScenarios"]),
    ]
)
