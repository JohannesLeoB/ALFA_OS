import Foundation

enum IMAPBodyStructureParser {
    private static let singlePartFields = 7

    static func parse(_ value: IMAPValue) throws -> IMAPBodyPart {
        guard let items = value.items else { throw MailFailure.malformedResponse("bodystructure") }
        return try node(items, section: items.first?.items != nil ? "" : "1")
    }

    private static func node(_ items: [IMAPValue], section: String) throws -> IMAPBodyPart {
        if items.first?.items != nil {
            var children: [IMAPBodyPart] = []
            var position = 0
            while position < items.count, let child = items[position].items {
                let childSection = section.isEmpty ? String(position + 1) : "\(section).\(position + 1)"
                children.append(try node(child, section: childSection))
                position += 1
            }
            let subtype = position < items.count ? (items[position].string ?? "").lowercased() : ""
            let parameters = position + 1 < items.count ? pairs(items[position + 1]) : [:]
            let (disposition, dispositionParameters) = dispositionFields(items, at: position + 2)
            return IMAPBodyPart(
                section: section, mediaType: "multipart", subtype: subtype, parameters: parameters, contentID: nil,
                encoding: "7bit", size: 0, disposition: disposition, dispositionParameters: dispositionParameters,
                children: children)
        }
        guard items.count >= singlePartFields else { throw MailFailure.malformedResponse("bodystructurePart") }
        let mediaType = (items[0].string ?? "").lowercased()
        let subtype = (items[1].string ?? "").lowercased()
        var position = singlePartFields
        var children: [IMAPBodyPart] = []
        if mediaType == "text" {
            position += 1
        } else if mediaType == "message", subtype == "rfc822" || subtype == "global" {
            if items.count > 9, let inner = items[8].items {
                let innerSection = inner.first?.items != nil ? section : "\(section).1"
                children = [try node(inner, section: innerSection)]
            }
            position += 3
        }
        let (disposition, dispositionParameters) = dispositionFields(items, at: position + 1)
        return IMAPBodyPart(
            section: section, mediaType: mediaType, subtype: subtype, parameters: pairs(items[2]),
            contentID: items[3].string?.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
            encoding: (items[5].string ?? "7bit").lowercased(), size: items[6].int ?? 0,
            disposition: disposition, dispositionParameters: dispositionParameters, children: children)
    }

    private static func dispositionFields(_ items: [IMAPValue], at index: Int) -> (String?, [String: String]) {
        guard index < items.count, let fields = items[index].items, !fields.isEmpty else { return (nil, [:]) }
        let name = fields[0].string?.lowercased()
        let parameters = fields.count > 1 ? pairs(fields[1]) : [:]
        return (name, parameters)
    }

    private static func pairs(_ value: IMAPValue) -> [String: String] {
        guard let items = value.items else { return [:] }
        var raw: [(String, String)] = []
        var position = 0
        while position + 1 < items.count {
            if let key = items[position].string, let text = items[position + 1].string {
                raw.append((key.lowercased(), text))
            }
            position += 2
        }
        return MIME.resolveExtended(raw)
    }
}
