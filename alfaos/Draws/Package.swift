// swift-tools-version: 6.2
import PackageDescription

let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "DrawingDude",
    defaultLocalization: "de",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Pages", targets: ["Pages"]),
        .library(name: "DrawingKit", targets: ["DrawingKit"]),
        .library(name: "DrawsAI", targets: ["DrawsAI"]),
        .library(name: "DrawsDock", targets: ["DrawsDock"]),
        .library(name: "Intake", targets: ["Intake"]),
        .library(name: "Templates", targets: ["Templates"]),
        .executable(name: "drawingdude", targets: ["drawingdude"]),
        .executable(name: "DrawingDudeApp", targets: ["DrawingDudeApp"])
    ],
    dependencies: [
        .package(path: "../Kit"),
        .package(path: "../../fundus/alpha"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(name: "Pages", swiftSettings: strict),
        .target(name: "DrawingKit", dependencies: ["Pages"], swiftSettings: strict),
        .target(name: "DrawsAI", dependencies: ["DrawingKit", .product(name: "AlfaServices", package: "alpha")], resources: [.copy("Resources/designer.md")], swiftSettings: strict),
        .target(name: "DrawsDock", dependencies: ["DrawingKit", .product(name: "AlfaServices", package: "alpha")], swiftSettings: strict),
        .target(name: "Intake", dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")], swiftSettings: strict),
        .target(name: "Templates", dependencies: ["Pages", "Intake"], swiftSettings: strict),
        .target(name: "DrawsFonts", dependencies: ["DrawingKit", .product(name: "ShellCore", package: "Kit")],
                resources: [.copy("Resources/Geist-VariableFont_wght.ttf")], swiftSettings: strict),
        .executableTarget(name: "drawingdude", dependencies: ["DrawingKit", "DrawsFonts"], swiftSettings: strict),
        .executableTarget(
            name: "DrawingDudeApp",
            dependencies: ["DrawingKit", "DrawsAI", "DrawsDock", "DrawsFonts", .product(name: "ShellCore", package: "Kit")],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
        .testTarget(name: "DrawsTests", dependencies: ["Pages", "DrawingKit", "DrawsAI", "DrawsDock", "DrawsFonts", "Intake", "Templates"], swiftSettings: strict)
    ]
)
