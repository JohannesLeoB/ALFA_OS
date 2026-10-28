import SwiftUI

struct HintPreference: PreferenceKey {
    struct Hint: Equatable {
        let key: String
        let point: CGPoint
    }

    static let defaultValue: Hint? = nil

    static func reduce(value: inout Hint?, nextValue: () -> Hint?) {
        value = value ?? nextValue()
    }
}
