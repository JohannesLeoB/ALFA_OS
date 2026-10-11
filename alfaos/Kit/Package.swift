// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AlfaKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ShellCore", targets: ["ShellCore"])
    ],
    targets: [
        .target(name: "ShellCore"),
        .testTarget(name: "ShellCoreTests", dependencies: ["ShellCore"])
    ]
)
