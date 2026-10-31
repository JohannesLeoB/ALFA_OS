import AppKit
import Design
import Hub

extension IntegrationLogo {
    var image: NSImage? { NSImage(named: resource) }

    var ground: KeyPath<Colors, ColorValue> {
        switch resource {
        case "claude": \.claudeClay
        case "sevdesk": \.sevdeskRed
        case "clockodo": \.clockodoBlue
        case "dhl": \.dhlYellow
        default: \.sheet
        }
    }

    func side(field: Double, mark: Double) -> CGFloat {
        switch kind {
        case .full: CGFloat(field)
        case .wide: CGFloat(field - Tokens.Spacing.step8)
        case .mark: CGFloat(mark)
        }
    }
}
