import Foundation
@testable import ShellCore

enum Fixture {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: repo.appendingPathComponent(path))
    }

    static func theme() throws -> TokenTheme {
        try TokenTheme(data: data("gestaltung/alfa-interface/tokens.json"))
    }

    static func metrics() throws -> ShellMetrics {
        try ShellMetrics(data: data("alfaos/App/Resources/shell.json"))
    }

    static func directory() throws -> AppDirectory {
        try AppDirectory(data: data("alfaos/App/Resources/apps.json"))
    }

    static func geometry() throws -> ShellGeometry {
        try ShellGeometry(theme: theme(), metrics: metrics())
    }

    static let screen = Size(width: 1512, height: 982)
}
