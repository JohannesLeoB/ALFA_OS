import Foundation

public extension WorkBasket {
    var vkNettoSumme: Double {
        picks.reduce(0.0) { sum, pick in
            sum + (pick.snapshot.vkEinzel ?? 0) * Double(pick.snapshot.quantity)
        }
    }

    var ekNettoSumme: Double {
        picks.reduce(0.0) { sum, pick in
            sum + (pick.snapshot.ekEinzel ?? 0) * Double(pick.snapshot.quantity)
        }
    }

    var margeNettoSumme: Double {
        vkNettoSumme - ekNettoSumme
    }

    var margeProzent: Double? {
        let vk = vkNettoSumme
        guard vk > 0 else { return nil }
        return margeNettoSumme / vk * 100
    }
}
