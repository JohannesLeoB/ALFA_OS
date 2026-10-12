// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AlfaKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "ShellCore", targets: ["ShellCore"]),
        .library(name: "Hub", targets: ["Hub"])
    ],
    dependencies: [
        .package(path: "../../fundus/alpha"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
    ],
    targets: [
        .target(name: "ShellCore"),
        .target(
            name: "Hub",
            dependencies: [
                .product(name: "MykilosServices", package: "alpha"),
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(name: "ShellCoreTests", dependencies: ["ShellCore"]),
        .testTarget(
            name: "HubTests",
            dependencies: [
                "Hub",
                .product(name: "MykilosServices", package: "alpha"),
                .product(name: "MykilosKit", package: "alpha")
            ]
        )
    ]
)
