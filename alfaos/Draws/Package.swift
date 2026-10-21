// swift-tools-version: 6.2
import PackageDescription

let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "DrawingDude",
    defaultLocalization: "de",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "DrawingKit", targets: ["DrawingKit"]),
        .library(name: "DrawsAI", targets: ["DrawsAI"]),
        .executable(name: "drawingdude", targets: ["drawingdude"]),
        .executable(name: "DrawingDudeApp", targets: ["DrawingDudeApp"])
    ],
    dependencies: [
        .package(path: "../Kit"),
        .package(path: "../../fundus/alpha")
    ],
    targets: [
        .target(name: "DrawingKit", swiftSettings: strict),
        .target(name: "DrawsAI", dependencies: ["DrawingKit", .product(name: "AlfaServices", package: "alpha")], resources: [.copy("Resources/designer.md")], swiftSettings: strict),
        .executableTarget(name: "drawingdude", dependencies: ["DrawingKit"], swiftSettings: strict),
        .executableTarget(
            name: "DrawingDudeApp",
            dependencies: ["DrawingKit", "DrawsAI", .product(name: "ShellCore", package: "Kit")],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
    ]
)
