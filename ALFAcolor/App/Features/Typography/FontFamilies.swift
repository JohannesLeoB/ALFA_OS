import CoreText

/// The font families installed on this Mac, sorted. Core Text is used here in the view layer only.
enum FontFamilies {
    static var installed: [String] {
        let names = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
