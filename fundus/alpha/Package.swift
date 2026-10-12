// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ALPHAFundus",
    defaultLocalization: "en",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "MykilosKit", targets: ["MykilosKit"]),
        .library(name: "MykilosKalkulationsCore", targets: ["MykilosKalkulationsCore"]),
        .library(name: "MykilosServices", targets: ["MykilosServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(name: "MykilosKit",
                path: "Sources/MykilosKit"),

        .target(name: "MykilosKalkulationsCore",
                path: "Sources/MykilosKalkulationsCore"),

        .target(name: "MykilosServices",
                dependencies: [
                    "MykilosKit",
                    "MykilosKalkulationsCore",
                    .product(name: "GRDB", package: "GRDB.swift"),
                ],
                path: "Sources/MykilosServices"),

        .testTarget(name: "MailTests",
                    dependencies: ["MykilosServices", "MykilosKit"],
                    path: "Tests/MailTests",
                    exclude: ["Fixtures"]),
    ]
)
