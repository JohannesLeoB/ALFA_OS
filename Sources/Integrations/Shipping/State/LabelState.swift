import Foundation
import Observation

@MainActor
@Observable
final class LabelState {
    enum Phase: Equatable, Sendable {
        case idle
        case creating
        case created
        case failed(String)
    }

    var projectNumber = ""
    var projectTitle = ""
    var recipientName = ""
    var recipientContact = ""
    var recipientStreet = ""
    var recipientHouseNumber = ""
    var recipientPostalCode = ""
    var recipientCity = ""
    var recipientCountry = "DEU"
    var sender: Address?
    var weightGrams = 1000
    var product = LabelOrder.defaultProduct
    var billingNumber = ""
    var referenceText = ""
    var lengthCm = 0
    var widthCm = 0
    var heightCm = 0
    var insuranceValue = 0.0
    var namedPersonOnly = false
    var bulky = false
    var signature = false

    public private(set) var phase: Phase = .idle
    public private(set) var result: LabelResult?
    public private(set) var issues: [LabelOrderIssue] = []

    private let label: any LabelPort

    init(label: any LabelPort, credentials: LabelCredentials? = nil) {
        self.label = label
        self.sender = credentials?.sender
        self.billingNumber = credentials?.billingNumber ?? ""
    }

    func setProject(number: String, title: String) {
        projectNumber = number
        projectTitle = title
        referenceText = ReferenceEngine.reference(projectNumber: number, projectName: title) ?? ""
    }

    @discardableResult
    func validate() -> [LabelOrderIssue] {
        guard let order = order() else {
            issues = LabelOrderIssue.allCases
            return issues
        }
        issues = LabelOrderEngine.issues(order)
        return issues
    }

    func createLabel() async {
        result = nil
        guard let order = order() else {
            phase = .failed(ShippingFailure.noCredentials.detail)
            return
        }
        let found = LabelOrderEngine.issues(order)
        guard found.isEmpty else {
            issues = found
            phase = .failed(ShippingFailure.incomplete(found).detail)
            return
        }
        phase = .creating
        do {
            result = try await label.createLabel(order)
            phase = .created
        } catch let failure as ShippingFailure {
            phase = .failed(failure.detail)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func order() -> LabelOrder? {
        guard let sender else { return nil }
        let recipient = Address(
            name1: recipientName, name2: recipientContact, street: recipientStreet, houseNumber: recipientHouseNumber,
            postalCode: recipientPostalCode, city: recipientCity, country: recipientCountry)
        let parcel = Parcel(lengthCm: lengthCm, widthCm: widthCm, heightCm: heightCm)
        let typed = referenceText.trimmingCharacters(in: .whitespaces)
        let reference = typed.isEmpty
            ? ReferenceEngine.reference(projectNumber: projectNumber, projectName: projectTitle)
            : String(typed.prefix(ReferenceEngine.maxLength))
        return LabelOrder(
            sender: sender, recipient: recipient, weightGrams: weightGrams, product: product,
            billingNumber: billingNumber, reference: reference, parcel: parcel.isComplete ? parcel : nil,
            insuranceValue: insuranceValue > 0 ? insuranceValue : nil, namedPersonOnly: namedPersonOnly,
            bulky: bulky, signature: signature)
    }
}
