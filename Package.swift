// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HushCore", targets: ["HushCore"]),
        .executable(name: "HushCheck", targets: ["HushCheck"]),
        .executable(name: "HushApp", targets: ["HushApp"]),
    ],
    targets: [
        // Pure, dependency-free logic. No AppKit / AVFoundation / Speech imports,
        // so the whole voice-sync pipeline is testable headlessly in CI.
        .target(name: "HushCore"),

        // Portable self-test: a Foundation-only runner that replays the synthetic
        // fixtures and asserts the acceptance gates. Runs with just Command Line
        // Tools (no Xcode / XCTest needed) — `swift run HushCheck`.
        .executableTarget(name: "HushCheck", dependencies: ["HushCore"]),

        // The macOS app shell (AppKit GhostPanel + notch overlay + SwiftUI).
        // Compiles with Command Line Tools; producing a signed .app bundle uses
        // the XcodeGen project in app/ (see README). Wires HushCore in M1.
        .executableTarget(name: "HushApp", dependencies: ["HushCore"]),
    ]
)
