// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimezoneMachine",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TimezoneCore"),
        .executableTarget(name: "TimezoneMachine", dependencies: ["TimezoneCore"]),
        // ponytail: assert-based check instead of a test target — this machine has Command Line
        // Tools only, which ship neither XCTest nor swift-testing. Run: swift run TimezoneCheck
        .executableTarget(name: "TimezoneCheck", dependencies: ["TimezoneCore"]),
    ]
)
