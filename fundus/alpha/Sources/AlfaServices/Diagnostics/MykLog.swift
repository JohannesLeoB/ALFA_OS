import Foundation
import AlfaKit
import os

public enum MykLog {
    public static let subsystem = AppKennung.bundleID

    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    public static let db        = Logger(subsystem: subsystem, category: "db")
    public static let drive     = Logger(subsystem: subsystem, category: "drive")
    public static let offers    = Logger(subsystem: subsystem, category: "offers")
    public static let chat      = Logger(subsystem: subsystem, category: "chat")
    public static let backup    = Logger(subsystem: subsystem, category: "backup")
    public static let contacts  = Logger(subsystem: subsystem, category: "contacts")
}
