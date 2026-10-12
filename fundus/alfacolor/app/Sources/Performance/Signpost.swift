import OSLog

/// Marks work on the canvas for Instruments (os_signpost, subsystem and category below).
/// Open the Points of Interest or the signpost track of a trace to see each interval with its duration.
public enum Signpost {
    public static let subsystem = "com.johannesleoberger.alfacolor"
    public static let category = "Canvas"

    static let signposter = OSSignposter(subsystem: subsystem, category: category)

    /// Runs `work` inside an interval with this name. The name is shown in Instruments.
    public static func interval<Result>(_ name: StaticString, _ work: () throws -> Result) rethrows -> Result {
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try work()
    }
}
