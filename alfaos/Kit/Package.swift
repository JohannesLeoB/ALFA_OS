// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AlfaKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ShellCore", targets: ["ShellCore"]),
        .library(name: "StudioCore", targets: ["StudioCore"])
    ],
    targets: [
        .target(name: "ShellCore"),
        .target(name: "StudioCore"),
        .testTarget(name: "ShellCoreTests", dependencies: ["ShellCore"])
    ]
)
