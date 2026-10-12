import Foundation

public enum ProviderCatalog {
    public static func standard(directory: URL, openBrowser: @escaping @Sendable (URL) async -> Bool) -> [any Provider] {
        var providers: [any Provider] = []
        if let config = try? GoogleClientConfig.load(from: directory) {
            providers.append(GoogleProvider(config: config, openBrowser: openBrowser))
        }
        providers.append(IMAPProvider())
        return providers
    }
}
