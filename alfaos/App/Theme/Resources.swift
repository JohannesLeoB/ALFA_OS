import Foundation
import ShellCore

struct ShellResources {
    let tokens: TokenTheme
    let metrics: ShellMetrics
    let directory: AppDirectory
    let geometry: ShellGeometry

    init(tokens: Data, metrics: Data, directory: Data) throws {
        self.tokens = try TokenTheme(data: tokens)
        self.metrics = try ShellMetrics(data: metrics)
        self.directory = try AppDirectory(data: directory)
        geometry = ShellGeometry(theme: self.tokens, metrics: self.metrics)
    }

    init(bundle: Bundle) throws {
        func read(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            return try Data(contentsOf: url)
        }
        try self.init(tokens: read("tokens"), metrics: read("shell"), directory: read("apps"))
    }
}
