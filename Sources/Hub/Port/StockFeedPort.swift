import Foundation

@MainActor
protocol StockFeedPort: AnyObject {
    func begin()
    func end()
    func apply(inlet: Inlet.ID, records: [any Item], at: Date)
    func drop(inlet: Inlet.ID)
    func disturb(_ hint: Hint)
}
