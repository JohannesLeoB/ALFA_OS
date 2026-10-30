import AppKit
import Design
import Hub

extension IntegrationLogo {
    var image: NSImage? { NSImage(named: resource) }

    var isWide: Bool { resource == "dhl" }

    var ground: KeyPath<Colors, ColorValue> { isWide ? \.dhlYellow : \.sheet }
}
