struct SRVRecord: Equatable, Sendable {
    let priority: Int
    let weight: Int
    let port: Int
    let target: String
}
