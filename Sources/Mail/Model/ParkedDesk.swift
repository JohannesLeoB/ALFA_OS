struct ParkedDesk: Equatable {
    var stack: [CardRef] = []
    var front: CardRef?
    var folder: String?
    var message: String?
}
