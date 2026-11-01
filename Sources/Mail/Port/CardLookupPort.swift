public protocol CardLookupPort {
    func cardID(forProvider provider: String) -> String?
}
