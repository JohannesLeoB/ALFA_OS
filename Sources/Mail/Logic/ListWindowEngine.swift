import Design

public enum ListWindowEngine {
    public static func spacer(count: Int, window: Int) -> Double {
        Double(max(0, count - window)) * Tokens.Size.mailRowEstimate
    }

    public static func remaining(content: Double, offset: Double, container: Double, spacer: Double) -> Double {
        content - spacer - offset - container
    }
}
