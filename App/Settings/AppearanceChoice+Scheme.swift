import Design
import SwiftUI

extension AppearanceChoice {
    var scheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
