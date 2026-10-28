struct ParkedMailbox {
    var stack: [CardRef] = []
    var front: CardRef?
    var message: String?
}
