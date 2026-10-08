// swift-tools-version: 6.0
// Setzkasten (Arbeitstitel): Kern der macOS-App als Swift-Paket.
// Jedes Ziel ist ohne Oberfläche testbar. Die App (SwiftUI) kommt als eigenes Ziel dazu.
import PackageDescription

let package = Package(
    name: "Setzkasten",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SetzkastenKit", targets: ["SetzkastenCore", "Geometry", "Tokens", "ColorLab", "AppTheme", "Document"])
    ],
    targets: [
        .target(name: "SetzkastenCore"),
        .target(name: "Geometry", dependencies: ["SetzkastenCore"]),
        .target(name: "Tokens", dependencies: ["SetzkastenCore"]),
        .target(name: "ColorLab", dependencies: ["Tokens"]),
        // E1: Gerüst vom Chef angelegt; Inhalt bauen B-103 (AppTheme) und B-104 (Document).
        .target(name: "AppTheme", dependencies: ["Tokens"]),
        .target(name: "Document", dependencies: ["SetzkastenCore", "Tokens"]),
        .testTarget(name: "SetzkastenTests", dependencies: ["SetzkastenCore", "Geometry", "Tokens", "ColorLab"]),
        .testTarget(name: "AppThemeTests", dependencies: ["AppTheme", "Tokens"]),
        .testTarget(name: "DocumentTests", dependencies: ["Document", "SetzkastenCore", "Tokens"], exclude: ["Fixtures"])
    ]
)
