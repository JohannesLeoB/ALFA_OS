import Foundation

public struct MailSignatureContact: Sendable, Equatable {
    public var name: String
    public var email: String?
    public var telefon: String?
    public var organisation: String?
    public var adresse: String?

    public enum Feld: String, Sendable, Equatable, CaseIterable {
        case name, email, telefon, organisation, adresse
    }

    public var geschaetzteFelder: Set<Feld>

    public init(name: String, email: String? = nil, telefon: String? = nil,
                organisation: String? = nil, adresse: String? = nil,
                geschaetzteFelder: Set<Feld> = []) {
        self.name = name
        self.email = email
        self.telefon = telefon
        self.organisation = organisation
        self.adresse = adresse
        self.geschaetzteFelder = geschaetzteFelder
    }
}

public enum MailSignatureParser {
    public static func parse(senderHeader: String, senderEmail: String, body: String) -> MailSignatureContact {
        let sigZeilen = signaturBlock(aus: body)
        var geschaetzt: Set<MailSignatureContact.Feld> = []

        let name: String
        if let kopfName = displayName(ausHeader: senderHeader) {
            name = kopfName
        } else if let sigName = personenName(inZeilen: sigZeilen) {
            name = sigName
            geschaetzt.insert(.name)
        } else {
            name = nameAusLokalteil(senderEmail)
            geschaetzt.insert(.name)
        }

        let email: String?
        if let sigMail = ersteEmail(inZeilen: sigZeilen) {
            email = sigMail
            if sigMail.caseInsensitiveCompare(senderEmail) != .orderedSame { geschaetzt.insert(.email) }
        } else {
            email = senderEmail.isEmpty ? nil : senderEmail
        }

        let telefon = ersteTelefonnummer(inZeilen: sigZeilen)
        if telefon != nil { geschaetzt.insert(.telefon) }

        let organisation = organisationszeile(inZeilen: sigZeilen)
        if organisation != nil { geschaetzt.insert(.organisation) }

        let adresse = anschrift(inZeilen: sigZeilen)
        if adresse != nil { geschaetzt.insert(.adresse) }

        return MailSignatureContact(
            name: name, email: email, telefon: telefon,
            organisation: organisation, adresse: adresse,
            geschaetzteFelder: geschaetzt
        )
    }

    static func signaturBlock(aus body: String) -> [String] {
        let ohneZitat = schneideZitatAb(body)
        let alleZeilen = ohneZitat
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        if let letzterTrenner = alleZeilen.lastIndex(where: { istSignaturTrenner($0) }) {
            let danach = alleZeilen[(letzterTrenner + 1)...]
            let rowItems = danach.map(trimmen).filter { !$0.isEmpty }
            if !rowItems.isEmpty { return Array(rowItems.prefix(10)) }
        }

        let nichtLeer = alleZeilen.map(trimmen).filter { !$0.isEmpty }
        return Array(nichtLeer.suffix(8))
    }

    static func schneideZitatAb(_ body: String) -> String {
        let rowItems = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        var result: [String] = []
        for rowItem in rowItems {
            let t = trimmen(rowItem)
            if istZitatMarker(t) { break }

            if t.hasPrefix(">") { break }
            result.append(rowItem)
        }
        return result.joined(separator: "\n")
    }

    private static func istSignaturTrenner(_ rowItem: String) -> Bool {
        let t = trimmen(rowItem)
        return t == "--" || t == "—" || rowItem == "-- "
    }

    private static let zitatMarker: [String] = [
        "-----ursprüngliche nachricht-----", "-----original message-----",
        "von:", "from:", "gesendet:", "sent:"
    ]
    private static func istZitatMarker(_ trimmedLower: String) -> Bool {
        let l = trimmedLower.lowercased()
        if zitatMarker.contains(where: { l.hasPrefix($0) }) { return true }

        if l.hasPrefix("am ") && l.hasSuffix("schrieb:") { return true }
        if l.hasPrefix("on ") && (l.hasSuffix("wrote:") || l.contains("> wrote:")) { return true }
        return false
    }

    static func displayName(ausHeader header: String) -> String? {
        var s = trimmen(header)
        if let open = s.firstIndex(of: "<") { s = trimmen(String(s[..<open])) }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        s = trimmen(s)
        guard !s.isEmpty, !s.contains("@"), s.contains(" ") else { return nil }
        return s
    }

    private static func nameAusLokalteil(_ email: String) -> String {
        let lokal = email.split(separator: "@").first.map(String.init) ?? email
        let teile = lokal.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" })
        let worte = teile.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        let name = worte.joined(separator: " ")
        return name.isEmpty ? email : name
    }

    static func personenName(inZeilen rowItems: [String]) -> String? {
        for rowItem in rowItems {
            let t = trimmen(rowItem)
            guard !t.contains("@"), !t.contains(":"), !enthaeltZiffer(t) else { continue }
            if enthaeltRechtsform(t) { continue }
            let worte = t.split(separator: " ").map(String.init)
            guard (2...3).contains(worte.count) else { continue }
            let alleGrossBeginnend = worte.allSatisfy { wort in
                guard let erster = wort.first else { return false }
                return erster.isUppercase && wort.count >= 2
            }
            if alleGrossBeginnend { return t }
        }
        return nil
    }

    static func ersteEmail(inZeilen rowItems: [String]) -> String? {
        for rowItem in rowItems {
            if let m = ersterTreffer(emailRegex, in: rowItem) { return m }
        }
        return nil
    }

    static func ersteTelefonnummer(inZeilen rowItems: [String]) -> String? {
        let sortiert = rowItems.sorted { hatTelefonLabel($0) && !hatTelefonLabel($1) }
        for rowItem in sortiert {
            if let roh = ersterTreffer(telefonRegex, in: rowItem) {
                let ziffern = roh.filter { $0.isNumber }

                if ziffern.count >= 7, !rowItem.lowercased().contains("fax") {
                    return trimmen(roh)
                }
            }
        }
        return nil
    }

    static func organisationszeile(inZeilen rowItems: [String]) -> String? {
        for rowItem in rowItems {
            let t = trimmen(rowItem)
            if enthaeltRechtsform(t), !t.contains("@"), t.count <= 60 { return t }
        }
        return nil
    }

    static func anschrift(inZeilen rowItems: [String]) -> String? {
        guard let plzIndex = rowItems.firstIndex(where: { istPlzOrtZeile($0) }) else { return nil }
        let plzOrt = trimmen(rowItems[plzIndex])

        if plzIndex > 0 {
            let davor = trimmen(rowItems[plzIndex - 1])
            if istStrassenZeile(davor) { return "\(davor), \(plzOrt)" }
        }
        return plzOrt
    }

    private static func hatTelefonLabel(_ rowItem: String) -> Bool {
        let l = rowItem.lowercased()
        return ["tel", "telefon", "mobil", "handy", "fon", "phone", "mob", "t:", "m:"]
            .contains { l.contains($0) }
    }

    private static func enthaeltRechtsform(_ rowItem: String) -> Bool {
        let formen = ["gmbh", "mbh", " ag", "ag ", " kg", "kg ", "e.k.", "e. k.", "e.g.",
                      " ug", "ug ", "ohg", "gbr", "& co", "ltd", "inc", "gmbh & co"]
        let l = " " + rowItem.lowercased() + " "
        return formen.contains { l.contains($0) }
    }

    private static func enthaeltZiffer(_ s: String) -> Bool { s.contains(where: { $0.isNumber }) }

    static func istPlzOrtZeile(_ rowItem: String) -> Bool {
        ersterTreffer(plzOrtRegex, in: rowItem) != nil
    }
    static func istStrassenZeile(_ rowItem: String) -> Bool {
        enthaeltZiffer(rowItem) && rowItem.contains(where: { $0.isLetter }) && !istPlzOrtZeile(rowItem)
            && rowItem.count <= 60
    }

    private static func trimmen(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let emailRegex = try! NSRegularExpression(
        pattern: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: [.caseInsensitive])
    private static let telefonRegex = try! NSRegularExpression(
        pattern: "\\+?\\d[\\d /().\\-]{6,}\\d", options: [])
    private static let plzOrtRegex = try! NSRegularExpression(
        pattern: "\\b\\d{5}\\s+\\p{L}", options: [])

    private static func ersterTreffer(_ regex: NSRegularExpression, in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }
}
