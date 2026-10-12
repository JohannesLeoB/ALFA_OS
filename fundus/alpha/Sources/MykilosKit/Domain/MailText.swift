import Foundation

public struct MailText: Sendable, Equatable {
    public let neuerText: String

    public let signatur: String?

    public let zitat: String?

    public var zitatZeilen: Int {
        guard let zitat, zitat.isEmpty == false else { return 0 }
        return zitat.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    public var hatZitat: Bool { (zitat?.isEmpty == false) }
    public var hatSignatur: Bool { (signatur?.isEmpty == false) }

    private static let signaturTrenner: Set<String> = ["-- ", "--"]

    private static func istZitatEinleitung(_ rowItem: String) -> Bool {
        let z = rowItem.trimmingCharacters(in: .whitespaces)
        guard z.hasSuffix(":") else { return false }
        let deutsch = z.hasPrefix("Am ") && z.contains("schrieb")
        let englisch = z.hasPrefix("On ") && z.contains("wrote")
        return deutsch || englisch
    }

    public static func zerlege(_ roh: String) -> MailText {
        let rowItems = roh.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var zitatStart: Int?
        for (i, rowItem) in rowItems.enumerated() {
            if istZitatEinleitung(rowItem) || rowItem.hasPrefix(">") {
                zitatStart = i
                break
            }
        }

        let headerRows = zitatStart.map { Array(rowItems[..<$0]) } ?? rowItems
        let zitat = zitatStart.map { Array(rowItems[$0...]).joined(separator: "\n") }

        var signaturStart: Int?
        for (i, rowItem) in headerRows.enumerated() where signaturTrenner.contains(rowItem) {
            signaturStart = i
        }

        let neu = (signaturStart.map { Array(headerRows[..<$0]) } ?? headerRows)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let signatur = signaturStart.map {
            Array(headerRows[($0 + 1)...]).joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if neu.isEmpty, signatur == nil || signatur?.isEmpty == true {
            return MailText(neuerText: roh.trimmingCharacters(in: .whitespacesAndNewlines),
                            signatur: nil, zitat: nil)
        }

        return MailText(
            neuerText: neu,
            signatur: (signatur?.isEmpty == false) ? signatur : nil,
            zitat: (zitat?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? zitat : nil)
    }

    public init(neuerText: String, signatur: String?, zitat: String?) {
        self.neuerText = neuerText
        self.signatur = signatur
        self.zitat = zitat
    }
}
