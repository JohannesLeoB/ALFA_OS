import Foundation

/// One character of a number, placed by its position from the end. Digits roll; other characters stay.
public struct RollingSlot: Equatable, Sendable {
    /// Position counted from the last character, so 0 is the ones place. It keeps its value when the length changes.
    public let fromEnd: Int
    public let character: Character
    /// The value of an ASCII digit, nil for any other character.
    public let digit: Int?
}

/// The digits of a number that roll when it changes.
public enum RollingDigits {
    /// Height of one digit row as a multiple of the font size.
    public static let rowFactor: CGFloat = 1.25

    private static let digits: [Character] = Array("0123456789")

    /// Slots of a text in reading order, from left to right.
    public static func slots(for text: String) -> [RollingSlot] {
        let characters = Array(text)
        return characters.enumerated().map { index, character in
            RollingSlot(fromEnd: characters.count - 1 - index,
                        character: character,
                        digit: digits.firstIndex(of: character))
        }
    }
}
