// swift-tools-version: 6.2
import PackageDescription

let strict: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "ALFA",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Design", targets: ["Design"]),
        .library(name: "Shell", targets: ["Shell"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Calculation", targets: ["Calculation"]),
        .library(name: "Hub", targets: ["Hub"]),
        .library(name: "Assistant", targets: ["Assistant"]),
        .library(name: "Mail", targets: ["Mail"]),
        .library(name: "Google", targets: ["Google"]),
        .library(name: "Airtable", targets: ["Airtable"]),
        .library(name: "ClickUp", targets: ["ClickUp"]),
        .library(name: "Sevdesk", targets: ["Sevdesk"]),
        .library(name: "Clockodo", targets: ["Clockodo"]),
        .library(name: "Shipping", targets: ["Shipping"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", exact: "6.29.3"),
    ],
    targets: [
        .target(name: "Core", path: "Sources/Core", swiftSettings: strict),
        .target(name: "Design", path: "Sources/Design", swiftSettings: strict),
        .target(name: "Shell", dependencies: ["Design"], path: "Sources/Shell", swiftSettings: strict),
        .target(
            name: "Storage",
            dependencies: ["Core", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Storage",
            swiftSettings: strict
        ),
        .target(
            name: "Hub",
            dependencies: ["Core", "Design", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Hub",
            swiftSettings: strict
        ),
        .target(
            name: "Mail",
            dependencies: ["Core", "Design", "Shell", "Storage", "Hub", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Mail",
            swiftSettings: strict
        ),
        .target(
            name: "Calculation",
            dependencies: ["Core", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Calculation",
            swiftSettings: strict
        ),
        .target(
            name: "Assistant",
            dependencies: ["Core", "Design", "Storage", "Hub", "Calculation", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Assistant",
            swiftSettings: strict
        ),
        .target(
            name: "Google",
            dependencies: ["Core", "Hub", "Mail", "Assistant"],
            path: "Sources/Integrations/Google",
            swiftSettings: strict
        ),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests", swiftSettings: strict),
        .testTarget(name: "DesignTests", dependencies: ["Design"], path: "Tests/DesignTests", swiftSettings: strict),
        .testTarget(name: "ShellTests", dependencies: ["Shell", "Core"], path: "Tests/ShellTests", swiftSettings: strict),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage", "Core", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/StorageTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "HubTests",
            dependencies: ["Hub", "Core", "Design", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/HubTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "MailTests",
            dependencies: ["Mail", "Core", "Design", "Shell", "Storage", "Hub", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/MailTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "CalculationTests",
            dependencies: ["Calculation", "Core", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/CalculationTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "AssistantTests",
            dependencies: ["Assistant", "Core", "Hub", "Calculation", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/AssistantTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "GoogleTests",
            dependencies: ["Google", "Core", "Hub", "Mail", "Assistant"],
            path: "Tests/GoogleTests",
            swiftSettings: strict
        ),
        .target(
            name: "Airtable",
            dependencies: ["Core", "Hub", "Assistant", "Calculation"],
            path: "Sources/Integrations/Airtable",
            swiftSettings: strict
        ),
        .target(
            name: "ClickUp",
            dependencies: ["Hub", "Assistant"],
            path: "Sources/Integrations/ClickUp",
            swiftSettings: strict
        ),
        .testTarget(
            name: "AirtableTests",
            dependencies: ["Airtable", "Core", "Hub", "Assistant", "Calculation", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/AirtableTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "ClickUpTests",
            dependencies: ["ClickUp", "Hub", "Assistant", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/ClickUpTests",
            swiftSettings: strict
        ),
        .target(
            name: "Sevdesk",
            dependencies: ["Hub", "Assistant", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Integrations/Sevdesk",
            swiftSettings: strict
        ),
        .target(
            name: "Clockodo",
            dependencies: ["Core", "Hub", "Assistant", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Integrations/Clockodo",
            swiftSettings: strict
        ),
        .target(
            name: "Shipping",
            dependencies: ["Core", "Hub", "Assistant"],
            path: "Sources/Integrations/Shipping",
            swiftSettings: strict
        ),
        .testTarget(
            name: "SevdeskTests",
            dependencies: ["Sevdesk", "Hub", "Assistant", "Storage"],
            path: "Tests/SevdeskTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "ClockodoTests",
            dependencies: ["Clockodo", "Core", "Hub", "Assistant", "Storage", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/ClockodoTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "ShippingTests",
            dependencies: ["Shipping", "Core", "Hub", "Assistant"],
            path: "Tests/ShippingTests",
            swiftSettings: strict
        ),
    ]
)
