// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ALPHAFundus",
    defaultLocalization: "en",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "AlfaKit", targets: ["AlfaKit"]),
        .library(name: "AlfaCalculation", targets: ["AlfaCalculation"]),
        .library(name: "AlfaServices", targets: ["AlfaServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(name: "AlfaKit",
                path: "Sources/AlfaKit"),

        .target(name: "AlfaCalculation",
                path: "Sources/AlfaCalculation"),

        .target(name: "AlfaServices",
                dependencies: [
                    "AlfaKit",
                    "AlfaCalculation",
                    .product(name: "GRDB", package: "GRDB.swift"),
                ],
                path: "Sources/AlfaServices"),

        .testTarget(name: "MailTests",
                    dependencies: ["AlfaServices", "AlfaKit"],
                    path: "Tests/MailTests",
                    exclude: ["Fixtures"]),
    ]
)
