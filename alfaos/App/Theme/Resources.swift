import Foundation
import ShellCore

struct ShellResources {
    let tokens: TokenTheme
    let directory: AppDirectory
    let geometry: ShellGeometry

    init(tokens: Data, directory: Data) throws {
        self.tokens = try TokenTheme(data: tokens)
        self.directory = try AppDirectory(data: directory)
        geometry = ShellGeometry()
    }

    init(bundle: Bundle) throws {
        func read(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            return try Data(contentsOf: url)
        }
        try self.init(tokens: read("tokens"), directory: read("apps"))
    }
}
