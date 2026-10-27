import Foundation

enum OfferClassificationEngine {
    static func classify(_ file: DriveFile, isIncoming: Bool, folderName: String?,
                         convention: OfferConvention) -> ClassifiedOffer {
        let prefix = self.prefix(of: file.name)
        let type = resolve(isIncoming: isIncoming, folder: (folderName ?? "").lowercased(), prefix: prefix,
                           convention: convention)
        return ClassifiedOffer(
            file: file, type: type,
            documentNumber: firstMatch(in: file.name, pattern: convention.documentNumberPattern),
            customerNumber: firstMatch(in: file.name, pattern: convention.customerNumberPattern),
            version: firstMatch(in: file.name, pattern: convention.versionPattern))
    }

    static func resolve(isIncoming: Bool, folder: String, prefix: String, convention: OfferConvention) -> OfferDocumentType {
        let known = convention.prefixes[prefix]
        if isIncoming {
            if folder.contains(convention.purchaseOrderFolderKeyword.lowercased()) { return .purchaseOrder }
            if known == .purchaseOrder { return .purchaseOrder }
            return .incomingOffer
        }
        if folder.contains(convention.invoiceFolderKeyword.lowercased()) {
            return known == .depositInvoice ? .depositInvoice : .finalInvoice
        }
        if folder.contains(convention.offerFolderKeyword.lowercased()) { return .offer }
        if folder.contains(convention.orderFolderKeyword.lowercased()) { return .orderConfirmation }
        return known ?? .other
    }

    static func prefix(of name: String) -> String {
        let base = name.split(separator: ".").first.map(String.init) ?? name
        return String(base.prefix { $0 != "-" && $0 != "_" }).uppercased()
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

struct ClassifiedOffer: Identifiable, Equatable, Sendable {
    var file: DriveFile
    var type: OfferDocumentType
    var documentNumber: String?
    var customerNumber: String?
    var version: String?

    var id: String { file.id }
}
