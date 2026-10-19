import Foundation
import AlfaServices

public enum ProjectCache {
    public static func clear(directory: URL? = nil) throws {
        try CachedProjectRegistry(directory: directory).clearCache()
    }
}
