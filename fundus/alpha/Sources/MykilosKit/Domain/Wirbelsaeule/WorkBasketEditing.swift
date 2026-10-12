import Foundation

public enum WorkBasketEditing {
    public static func aktualisierePosition(
        _ basket: WorkBasket,
        anIndex index: Int,
        quantity: Int? = nil,
        vkEinzel: Double? = nil
    ) -> WorkBasket {
        guard basket.status.istEingefroren == false else { return basket }
        guard basket.picks.indices.contains(index) else { return basket }

        var picks = basket.picks
        let alt = picks[index]
        let s = alt.snapshot
        let neuSnapshot = PickSnapshot(
            label: s.label,
            quantity: quantity.map { max(0, $0) } ?? s.quantity,
            ekEinzel: s.ekEinzel,
            vkEinzel: vkEinzel ?? s.vkEinzel,
            attribute: s.attribute
        )
        picks[index] = BasicPick(
            matrix: alt.matrix,
            objektID: alt.objektID,
            snapshot: neuSnapshot,
            content: (alt as? BasicPick)?.content ?? .keiner
        )
        var neu = basket
        neu.picks = picks
        return neu
    }

    public static func entfernePosition(_ basket: WorkBasket, anIndex index: Int) -> WorkBasket {
        guard basket.status.istEingefroren == false else { return basket }
        guard basket.picks.indices.contains(index) else { return basket }
        var neu = basket
        neu.picks.remove(at: index)
        return neu
    }
}
