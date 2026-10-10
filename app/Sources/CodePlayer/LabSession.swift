/// The lab for one code card: the draft, its controls, the view options and the versions of the card.
/// It keeps its state while the lab is closed, so the draft is there when the lab opens again.
public struct LabSession: Equatable, Sendable {
    public private(set) var draft: LabDraft
    /// The tab that the editor shows.
    public private(set) var tab: LabDraft.Tab
    public private(set) var controls: [LabControl]
    /// The properties of the component of a React card. Empty for other cards.
    public private(set) var props: [LabProp]
    /// The versions of the card. The current one is the last saved draft.
    public private(set) var versions: VersionLog<LabDraft>
    public var zoom: LabZoom = .fit
    public var showsGrid = false
    public var showsGuides = false
    public var isDark = false
    /// True once the user picked the art. The lab then never changes it by itself.
    public private(set) var artIsChosen = false

    /// `older` are the versions the card already has, oldest first. The lab starts with them.
    public init(draft: LabDraft, older: [LabDraft] = []) {
        self.draft = draft
        self.tab = LabSession.firstTab(of: draft)
        self.controls = LabControls.read(draft)
        self.props = LabSession.readProps(draft)
        self.versions = VersionLog(current: draft, older: older)
        chooseArt(for: [draft.html, draft.script].filter { !LabHints.isBlank($0) }.joined(separator: "\n"), onOpen: true)
    }

    /// Shows another tab of the draft's art.
    public mutating func show(_ tab: LabDraft.Tab) {
        guard draft.tabs.contains(tab) else { return }
        self.tab = tab
    }

    /// Changes the text of a tab. The controls follow the code, and a pending value stays where the code still declares the same value.
    public mutating func edit(_ text: String, in tab: LabDraft.Tab) {
        guard draft.text(tab) != text else { return }
        draft.setText(text, for: tab)
        refreshControls()
    }

    /// Changes the art. Tabs that the new art lacks are left, and the editor shows the first tab of the art.
    public mutating func setArt(_ art: LabDraft.Art) {
        artIsChosen = true
        guard art != draft.art else { return }
        draft.art = art
        if !draft.tabs.contains(tab) { tab = LabSession.firstTab(of: draft) }
        refreshControls()
    }

    /// Changes the width in points. 0 fills the frame.
    public mutating func setWidth(_ width: Double) {
        draft.width = width
    }

    /// Sets a number control. Nothing changes for an unknown name or a colour.
    public mutating func setNumber(_ number: Double, for name: String) {
        guard let index = controls.firstIndex(where: { $0.name == name }) else { return }
        controls[index].setNumber(number)
    }

    /// Sets a colour control. Nothing changes for an unknown name or a number.
    public mutating func setColour(_ hex: String, for name: String) {
        guard let index = controls.firstIndex(where: { $0.name == name }) else { return }
        controls[index].setColour(hex)
    }

    /// Sets a property. Nothing changes for an unknown name or a value of another kind.
    public mutating func setProp(_ value: LabProp.Value, for name: String) {
        guard let index = props.firstIndex(where: { $0.name == name }) else { return }
        props[index].set(value)
    }

    /// Routes pasted text. Style sheets and scripts go to their tab, which then opens. Other text goes to the open tab.
    public mutating func paste(_ text: String) {
        chooseArt(for: text, onOpen: false)
        let routed = draft.art == .react ? nil : LabPaste.target(for: text)
        let destination = routed.flatMap { draft.tabs.contains($0) ? $0 : nil } ?? tab
        let existing = draft.text(destination)
        let joined = existing.isEmpty ? text : existing + "\n" + text
        show(destination)
        edit(joined, in: destination)
    }

    /// Takes the draft and the controls of the card again, for a card that changed on the board. The view options stay.
    public mutating func reset(to board: LabDraft) {
        draft = board
        tab = LabSession.firstTab(of: board)
        controls = LabControls.read(board)
        props = LabSession.readProps(board)
    }

    /// Writes the changed control values into the code and saves the result as the newest version of the card.
    /// `board` is the draft of the card as it is on the board. A board version that the lab has not seen is kept first.
    /// The controls then start again from the saved values.
    @discardableResult
    public mutating func commit(over board: LabDraft) -> LabDraft {
        let saved = LabWriteBack.applyProps(props, to: LabWriteBack.apply(controls, to: draft))
        versions.save(board)
        versions.save(saved)
        draft = saved
        controls = LabControls.read(saved)
        props = LabSession.readProps(saved)
        return saved
    }

    /// Picks the art that the code asks for, unless the user picked one. A piece such as a style sheet keeps the art.
    /// React code that sits in the markup tab moves to the script tab. On opening, only a plain page can change.
    private mutating func chooseArt(for text: String, onOpen: Bool) {
        guard !artIsChosen, let art = LabReading(text).art, art != draft.art else { return }
        if onOpen && (draft.art != .html || art == .html) { return }
        if art == .react {
            // Markup that is already in the draft would vanish from the React art, so a paste leaves the art then.
            if !onOpen && !LabHints.isBlank(draft.html) { return }
            if LabHints.isBlank(draft.script) {
                draft.script = draft.html
                draft.html = ""
            }
        }
        draft.art = art
        tab = LabSession.firstTab(of: draft)
        controls = LabControls.read(draft)
        props = LabSession.readProps(draft)
        versions = VersionLog(current: draft, older: versions.older)
    }

    /// Why the page cannot play the code. nil when it can.
    /// Only a draft with one filled tab is read, so that pieces of a page are never taken for a note.
    public var blocked: LabBlock? {
        let filled = draft.tabs.map { draft.text($0) }.filter { !LabHints.isBlank($0) }
        guard filled.count == 1, let text = filled.first else { return nil }
        switch LabReading(text).classification.kind {
        case .foreign(let language):
            switch language {
            case .swift: return .swift
            case .kotlin: return .kotlin
            case .java: return .java
            case .dart: return .dart
            case .python: return .python
            }
        case .json: return .json
        case .notCode: return .note
        case .html, .css, .tailwind, .react, .script, .svg: return nil
        }
    }

    private mutating func refreshControls() {
        let earlier = controls
        controls = LabControls.read(draft).map { fresh in
            guard let previous = earlier.first(where: { $0.name == fresh.name }) else { return fresh }
            return fresh.carrying(previous)
        }
        let earlierProps = props
        props = LabSession.readProps(draft).map { fresh in
            guard let previous = earlierProps.first(where: { $0.name == fresh.name }), previous.initial == fresh.initial,
                  previous.kind == fresh.kind else { return fresh }
            var copy = fresh
            copy.set(previous.value)
            return copy
        }
    }

    /// The properties of a React draft: the parameters of its component in the script tab.
    static func readProps(_ draft: LabDraft) -> [LabProp] {
        draft.art == .react ? LabPropsReader.read(draft.script) : []
    }

    private static func firstTab(of draft: LabDraft) -> LabDraft.Tab {
        draft.art == .react ? .script : .html
    }
}
