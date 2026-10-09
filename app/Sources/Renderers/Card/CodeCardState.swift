/// What a code card shows: its player, its source or both.
public enum CodeView: String, CaseIterable, Sendable {
    case player, source, both
}

/// The state of a code card on the canvas. It holds no page and no text; the view asks the renderer for those.
/// A card that cannot run shows its source only.
public struct CodeCardState: Equatable, Sendable {
    public private(set) var view: CodeView
    /// Whether the live page runs. A card that rests shows its still image.
    public private(set) var isPlaying = false
    public private(set) var canPlay: Bool
    /// The file names in list order.
    public private(set) var fileNames: [String]
    /// The file that the source shows. nil when the card has no file.
    public private(set) var file: String?

    public init(fileNames: [String], canPlay: Bool) {
        self.canPlay = canPlay
        self.fileNames = CodeFiles.ordered(fileNames)
        self.view = canPlay ? .player : .source
        self.file = self.fileNames.first
    }

    /// The player is part of the card, and the card can run.
    public var showsPlayer: Bool { canPlay && view != .source }
    public var showsSource: Bool { view != .player }
    /// The live page is on the canvas.
    public var isLive: Bool { showsPlayer && isPlaying }
    /// The player is on the canvas but rests as a still image.
    public var isResting: Bool { showsPlayer && !isPlaying }

    /// Shows another view. A card that cannot run stays on its source. Showing the source stops the page.
    public mutating func show(_ view: CodeView) {
        guard canPlay else {
            self.view = .source
            isPlaying = false
            return
        }
        self.view = view
        if view == .source { isPlaying = false }
    }

    /// Starts the page. Nothing happens when the player is not on the canvas.
    public mutating func play() {
        guard showsPlayer else { return }
        isPlaying = true
    }

    public mutating func rest() {
        isPlaying = false
    }

    /// Chooses the file that the source shows. Names that the card does not have are ignored.
    public mutating func select(_ name: String) {
        guard fileNames.contains(name) else { return }
        file = name
    }

    /// Takes the files and the playability of the card again, after an edit. The view stays where it still applies.
    public mutating func update(fileNames: [String], canPlay: Bool) {
        let wasPlayable = self.canPlay
        self.fileNames = CodeFiles.ordered(fileNames)
        self.canPlay = canPlay
        if !canPlay {
            view = .source
            isPlaying = false
        } else if !wasPlayable {
            view = .player
        }
        if let file, self.fileNames.contains(file) { return }
        file = self.fileNames.first
    }
}
