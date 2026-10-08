// swift-tools-version: 6.0
// Setzkasten (Arbeitstitel): Kern der macOS-App als Swift-Paket.
// Jedes Ziel ist ohne Oberfläche testbar. Die App (SwiftUI) kommt als eigenes Ziel dazu.
import PackageDescription

let package = Package(
    name: "Setzkasten",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SetzkastenKit", targets: ["SetzkastenCore", "Geometry", "Tokens", "ColorLab"])
    ],
    targets: [
        .target(name: "SetzkastenCore"),
        .target(name: "Geometry", dependencies: ["SetzkastenCore"]),
        .target(name: "Tokens", dependencies: ["SetzkastenCore"]),
        .target(name: "ColorLab", dependencies: ["Tokens"]),
        .testTarget(name: "SetzkastenTests", dependencies: ["SetzkastenCore", "Geometry", "Tokens", "ColorLab"])
    ]
)
