import os

public enum Log {
    public static let subsystem = AppIdentity.bundleID

    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
