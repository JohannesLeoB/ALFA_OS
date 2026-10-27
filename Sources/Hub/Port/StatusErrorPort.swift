public protocol StatusErrorPort: Error {
    var status: Int { get }
}
