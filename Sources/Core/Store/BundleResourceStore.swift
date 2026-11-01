import Foundation

public struct BundleResourceStore {
    private let bundle: Bundle

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    public func data(forResource name: String, withExtension fileExtension: String) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
