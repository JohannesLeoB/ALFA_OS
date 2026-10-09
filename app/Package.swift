// swift-tools-version: 6.0
// ALFAcolor: core of the macOS app as a Swift package.
// Every target can be tested without a UI. The app (SwiftUI) is its own target in ALFAcolor/project.yml.
import PackageDescription

let package = Package(
    name: "ALFAcolor",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ALFAcolorKit", targets: ["ALFAcolorCore", "Geometry", "Tokens", "ColorLab", "AppTheme", "Document", "BoardModel", "Thumbnails", "Importers", "Renderers", "Motion", "Exporters", "Performance"])
    ],
    targets: [
        .target(name: "ALFAcolorCore"),
        .target(name: "Motion"),
        .target(name: "Geometry", dependencies: ["ALFAcolorCore"]),
        .target(name: "Tokens", dependencies: ["ALFAcolorCore"]),
        .target(name: "ColorLab", dependencies: ["Tokens"]),
        .target(name: "AppTheme", dependencies: ["Tokens"]),
        .target(name: "Document", dependencies: ["ALFAcolorCore", "Tokens"]),
        .target(name: "BoardModel", dependencies: ["ALFAcolorCore", "Geometry", "Document"]),
        .target(name: "Thumbnails", dependencies: ["Document"]),
        .target(name: "Importers", dependencies: ["ALFAcolorCore", "Document", "BoardModel"]),
        .target(name: "Renderers", dependencies: ["ALFAcolorCore"]),
        .target(name: "Exporters", dependencies: ["ALFAcolorCore", "Document", "BoardModel", "Tokens", "Geometry"]),
        .target(name: "Performance", dependencies: ["ALFAcolorCore", "Document", "BoardModel", "Geometry"]),
        .testTarget(name: "ALFAcolorCoreTests", dependencies: ["ALFAcolorCore", "Geometry", "Tokens", "ColorLab"]),
        .testTarget(name: "AppThemeTests", dependencies: ["AppTheme", "Tokens"]),
        .testTarget(name: "DocumentTests", dependencies: ["Document", "ALFAcolorCore", "Tokens"], exclude: ["Fixtures"]),
        .testTarget(name: "BoardModelTests", dependencies: ["BoardModel", "ALFAcolorCore", "Document", "Geometry"]),
        .testTarget(name: "ThumbnailsTests", dependencies: ["Thumbnails", "Document"]),
        .testTarget(name: "ImportersTests", dependencies: ["Importers", "ALFAcolorCore", "Document", "BoardModel", "Renderers"]),
        .testTarget(name: "RenderersTests", dependencies: ["Renderers", "ALFAcolorCore"]),
        .testTarget(name: "ExportersTests", dependencies: ["Exporters", "ALFAcolorCore", "Document", "BoardModel", "Tokens", "Geometry"]),
        .testTarget(name: "PerformanceTests", dependencies: ["Performance", "ALFAcolorCore", "Document", "BoardModel", "Geometry"]),
        .testTarget(name: "MotionTests", dependencies: ["Motion"])
    ]
)
