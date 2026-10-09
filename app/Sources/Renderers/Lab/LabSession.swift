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

    public init(draft: LabDraft) {
        self.draft = draft
        self.tab = LabSession.firstTab(of: draft)
        self.controls = LabControls.read(draft)
        self.props = LabSession.readProps(draft)
        self.versions = VersionLog(current: draft)
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
        let saved = LabWriteBack.apply(controls, to: draft)
        versions.save(board)
        versions.save(saved)
        draft = saved
        controls = LabControls.read(saved)
        return saved
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
