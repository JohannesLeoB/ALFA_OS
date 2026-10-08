// swift-tools-version: 6.0
// ALFAcolor: Kern der macOS-App als Swift-Paket.
// Jedes Ziel ist ohne Oberfläche testbar. Die App (SwiftUI) kommt als eigenes Ziel dazu.
import PackageDescription

let package = Package(
    name: "ALFAcolor",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ALFAcolorKit", targets: ["ALFAcolorCore", "Geometry", "Tokens", "ColorLab", "AppTheme", "Document"])
    ],
    targets: [
        .target(name: "ALFAcolorCore"),
        .target(name: "Geometry", dependencies: ["ALFAcolorCore"]),
        .target(name: "Tokens", dependencies: ["ALFAcolorCore"]),
        .target(name: "ColorLab", dependencies: ["Tokens"]),
        // E1: Gerüst vom Chef angelegt; Inhalt bauen B-103 (AppTheme) und B-104 (Document).
        .target(name: "AppTheme", dependencies: ["Tokens"]),
        .target(name: "Document", dependencies: ["ALFAcolorCore", "Tokens"]),
        .testTarget(name: "ALFAcolorCoreTests", dependencies: ["ALFAcolorCore", "Geometry", "Tokens", "ColorLab"]),
        .testTarget(name: "AppThemeTests", dependencies: ["AppTheme", "Tokens"]),
        .testTarget(name: "DocumentTests", dependencies: ["Document", "ALFAcolorCore", "Tokens"], exclude: ["Fixtures"])
    ]
)
