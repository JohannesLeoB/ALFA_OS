import Foundation

public struct MailLeadVorschlag: Equatable, Sendable {
    public enum Herkunft: String, Equatable, Sendable {
        case absender

        case signatur

        public var hint: String {
            switch self {
            case .absender: "aus dem Absender"
            case .signatur: "aus der Signatur erkannt — bitte prüfen"
            }
        }
    }

    public struct Feld: Equatable, Sendable {
        public let value: String
        public let herkunft: Herkunft
        public init(value: String, herkunft: Herkunft) { self.value = value; self.herkunft = herkunft }
    }

    public var vorname: Feld?
    public var nachname: Feld?
    public var email: Feld?
    public var telefon: Feld?
    public var strasse: Feld?
    public var houseNumber: Feld?
    public var plz: Feld?
    public var ort: Feld?

    public var projektname: Feld?

    public var quellMessageID: String?

    public init() {}

    public var fehlendFuerLead: [String] {
        var offen: [String] = []
        if nachname?.value.isEmpty ?? true { offen.append("Nachname") }
        if (strasse?.value.isEmpty ?? true) && (ort?.value.isEmpty ?? true) {
            offen.append("Adresse (Straße oder Ort — sonst kein Drive-Ordner)")
        }
        return offen
    }
}

public enum MailLeadExtraktor {
    public static func extrahiere(
        fromRaw: String, betreff: String, text: String, messageID: String? = nil
    ) -> MailLeadVorschlag {
        var v = MailLeadVorschlag()
        v.quellMessageID = messageID

        let (anzeigename, adresse) = zerlegeFrom(fromRaw)
        if let adresse { v.email = .init(value: adresse, herkunft: .absender) }
        if let anzeigename, let (vor, nach) = zerlegeName(anzeigename) {
            if let vor { v.vorname = .init(value: vor, herkunft: .absender) }
            v.nachname = .init(value: nach, herkunft: .absender)
        }

        let sauberBetreff = betreffOhnePraefix(betreff)
        if sauberBetreff.isEmpty == false {
            v.projektname = .init(value: sauberBetreff, herkunft: .absender)
        }

        if let telefon = findeTelefon(text) { v.telefon = .init(value: telefon, herkunft: .signatur) }
        if let (plz, ort) = findePLZOrt(text) {
            v.plz = .init(value: plz, herkunft: .signatur)
            v.ort = .init(value: ort, herkunft: .signatur)
        }
        if let (strasse, number) = findeStrasse(text) {
            v.strasse = .init(value: strasse, herkunft: .signatur)
            if let number { v.houseNumber = .init(value: number, herkunft: .signatur) }
        }
        return v
    }

    static func betreffOhnePraefix(_ betreff: String) -> String {
        let praefixe = ["re:", "aw:", "antw:", "fwd:", "fw:", "wg:"]
        var text = betreff.trimmingCharacters(in: .whitespacesAndNewlines)
        var nochmal = true
        while nochmal {
            nochmal = false
            for praefix in praefixe where text.lowercased().hasPrefix(praefix) {
                text = String(text.dropFirst(praefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                nochmal = true
                break
            }
        }
        return text
    }

    static func zerlegeFrom(_ roh: String) -> (String?, String?) {
        let text = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.lastIndex(of: "<"), let ende = text.lastIndex(of: ">"), start < ende else {
            let nurAdresse = text.contains("@") ? text : nil
            return (nil, nurAdresse)
        }
        let adresse = String(text[text.index(after: start)..<ende])
            .trimmingCharacters(in: .whitespaces)
        var name = String(text[text.startIndex..<start])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        if name.isEmpty { return (nil, adresse.isEmpty ? nil : adresse) }

        if let komma = name.firstIndex(of: ",") {
            let nach = String(name[name.startIndex..<komma]).trimmingCharacters(in: .whitespaces)
            let vor = String(name[name.index(after: komma)...]).trimmingCharacters(in: .whitespaces)
            if vor.isEmpty == false { name = "\(vor) \(nach)" }
        }
        return (name, adresse.isEmpty ? nil : adresse)
    }

    static func zerlegeName(_ name: String) -> (String?, String)? {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sauber.isEmpty == false, sauber.contains("@") == false else { return nil }
        let teile = sauber.split(separator: " ").map(String.init)
        guard let nachname = teile.last else { return nil }
        let vorname = teile.dropLast().joined(separator: " ")
        return (vorname.isEmpty ? nil : vorname, nachname)
    }

    static func findeTelefon(_ text: String) -> String? {
        let patterns = #"(?:(?:\+|00)\d{1,3}[\s/()-]*)?(?:\(?0\)?[\s/-]*)?\d{2,5}[\s/-]*\d{3,}[\s\d/-]*"#
        guard let regex = try? NSRegularExpression(pattern: patterns) else { return nil }
        let area = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: area) {
            guard let r = Range(match.range, in: text) else { continue }
            let kandidat = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard kandidat.filter(\.isNumber).count >= 7 else { continue }
            if let normalisiert = TelefonFormat.normalisiere(kandidat).value { return normalisiert }
        }
        return nil
    }

    static func findePLZOrt(_ text: String) -> (String, String)? {
        for rowItem in text.split(whereSeparator: \.isNewline) {
            let z = rowItem.trimmingCharacters(in: .whitespaces)
            let teile = z.split(separator: " ").map(String.init)
            guard let index = teile.firstIndex(where: { istPLZ($0) }), index + 1 < teile.count
            else { continue }
            let ort = teile[(index + 1)...].joined(separator: " ")
                .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;"))
            guard ort.isEmpty == false, ort.allSatisfy({ $0.isNumber }) == false else { continue }
            return (teile[index], ort)
        }
        return nil
    }

    static func istPLZ(_ token: String) -> Bool {
        let t = token.trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
        return t.count == 5 && t.allSatisfy { $0.isNumber && $0.isASCII }
    }

    static func findeStrasse(_ text: String) -> (String, String?)? {
        let endungen = ["straße", "strasse", "str.", "str", "weg", "allee", "platz", "gasse",
                        "ufer", "ring", "damm", "chaussee", "pfad", "steig"]
        for rowItem in text.split(whereSeparator: \.isNewline) {
            let z = rowItem.trimmingCharacters(in: CharacterSet(charactersIn: " ,;"))
            guard z.isEmpty == false, z.count <= 60 else { continue }

            if z.split(separator: " ").contains(where: { istPLZ(String($0)) }) { continue }
            let klein = z.lowercased()
            guard endungen.contains(where: { wort in
                klein.split(whereSeparator: { $0 == " " || $0 == "-" })
                    .contains { $0.hasSuffix(wort) || $0 == wort }
            }) else { continue }
            let geteilt = AdresseAufteilung.teile(z)
            guard geteilt.unklar == false, geteilt.houseNumber != nil else { continue }
            return (geteilt.strasse, geteilt.houseNumber)
        }
        return nil
    }
}

public struct MailLeadQuelle: Equatable, Sendable {
    public let betreff: String
    public let absenderHeader: String
    public let empfangenAm: Date?
    public let text: String
    public let messageID: String

    public init(betreff: String, absenderHeader: String, empfangenAm: Date?,
                text: String, messageID: String) {
        self.betreff = betreff
        self.absenderHeader = absenderHeader
        self.empfangenAm = empfangenAm
        self.text = text
        self.messageID = messageID
    }

    public static let maxZeilen = 400

    public func pdfInhalt() -> (felder: [(label: String, value: String)], rowItems: [[String]]) {
        var felder: [(String, String)] = []
        if absenderHeader.isEmpty == false { felder.append(("Von", absenderHeader)) }
        if betreff.isEmpty == false { felder.append(("Betreff", betreff)) }
        if let empfangenAm {
            let fmt = DateFormatter()
            fmt.dateFormat = "dd.MM.yyyy HH:mm"
            fmt.locale = Locale(identifier: "de_DE")
            felder.append(("Empfangen", fmt.string(from: empfangenAm)))
        }
        if messageID.isEmpty == false { felder.append(("Message-ID", messageID)) }

        var rowItems = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { [String($0)] }
        if rowItems.count > Self.maxZeilen {
            let rest = rowItems.count - Self.maxZeilen
            rowItems = Array(rowItems.prefix(Self.maxZeilen))
            rowItems.append(["… [\(rest) weitere Zeilen gekappt — Original in Gmail, Message-ID oben]"])
        }
        return (felder, rowItems)
    }

    public func fileName(projektNummerApp: String, date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.locale = Locale(identifier: "de_DE")
        return "\(fmt.string(from: date))_Quellmail_\(projektNummerApp).pdf"
    }
}
