import Core
import Foundation

struct Address: Sendable, Equatable {
    var name1: String
    var name2: String?
    var street: String
    var houseNumber: String
    var postalCode: String
    var city: String
    var country: String

    init(
        name1: String, name2: String? = nil, street: String, houseNumber: String, postalCode: String, city: String,
        country: String = "DEU"
    ) {
        self.name1 = name1
        let trimmed = name2?.trimmingCharacters(in: .whitespaces)
        self.name2 = trimmed?.isEmpty == false ? trimmed : nil
        self.street = street
        self.houseNumber = houseNumber
        self.postalCode = postalCode
        self.city = city
        self.country = country
    }

    var streetLine: String {
        houseNumber.isEmpty ? street : "\(street) \(houseNumber)"
    }

    static func parsed(
        name: String, line: String?, postalCode: String?, city: String?, country: String = "DEU"
    ) -> Address {
        let split = AddressSplitParser.parse(line ?? "")
        return Address(
            name1: name.trimmingCharacters(in: .whitespaces),
            street: split.street.trimmingCharacters(in: .whitespaces),
            houseNumber: (split.houseNumber ?? "").trimmingCharacters(in: .whitespaces),
            postalCode: (postalCode ?? "").trimmingCharacters(in: .whitespaces),
            city: (city ?? "").trimmingCharacters(in: .whitespaces),
            country: country)
    }
}
