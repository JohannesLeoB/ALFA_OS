// swift-tools-version: 6.2
import PackageDescription

let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "AlfaKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "ShellCore", targets: ["ShellCore"]),
        .library(name: "Hub", targets: ["Hub"]),
        .library(name: "Mail", targets: ["Mail"])
    ],
    dependencies: [
        .package(path: "../../fundus/alpha"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
    ],
    targets: [
        .target(name: "ShellCore", swiftSettings: strict),
        .target(
            name: "Hub",
            dependencies: [
                .product(name: "MykilosServices", package: "alpha"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            swiftSettings: strict
        ),
        .target(
            name: "Mail",
            dependencies: [
                "Hub",
                .product(name: "MykilosServices", package: "alpha"),
                .product(name: "MykilosKit", package: "alpha"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            swiftSettings: strict
        ),
        .testTarget(name: "ShellCoreTests", dependencies: ["ShellCore"], swiftSettings: strict),
        .testTarget(
            name: "HubTests",
            dependencies: [
                "Hub",
                .product(name: "MykilosServices", package: "alpha"),
                .product(name: "MykilosKit", package: "alpha")
            ],
            swiftSettings: strict
        ),
        .testTarget(
            name: "MailTests",
            dependencies: [
                "Mail",
                "Hub",
                .product(name: "MykilosServices", package: "alpha"),
                .product(name: "MykilosKit", package: "alpha")
            ],
            swiftSettings: strict
        )
    ]
)
