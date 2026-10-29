import Foundation

enum MessageParser {
    struct ListPage: Equatable {
        var ids: [String]
        var nextPageToken: String?
        var estimate: Int?
    }

    static func listPage(from data: Data) throws -> ListPage {
        struct Reference: Decodable { var id: String }
        struct Response: Decodable {
            var messages: [Reference]?
            var nextPageToken: String?
            var resultSizeEstimate: Int?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw GoogleFailure.decodingFailed }
        return ListPage(ids: (decoded.messages ?? []).map(\.id), nextPageToken: decoded.nextPageToken,
                        estimate: decoded.resultSizeEstimate)
    }

    struct HistoryPage: Equatable {
        var ids: Set<String>
        var historyID: String?
        var nextPageToken: String?
    }

    static func historyPage(from data: Data) throws -> HistoryPage {
        struct Reference: Decodable { var id: String }
        struct Change: Decodable { var message: Reference }
        struct Record: Decodable {
            var messages: [Reference]?
            var labelsAdded: [Change]?
            var labelsRemoved: [Change]?
        }
        struct Response: Decodable {
            var history: [Record]?
            var historyId: String?
            var nextPageToken: String?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw GoogleFailure.decodingFailed }
        var ids = Set<String>()
        for record in decoded.history ?? [] {
            ids.formUnion((record.messages ?? []).map(\.id))
            ids.formUnion((record.labelsAdded ?? []).map(\.message.id))
            ids.formUnion((record.labelsRemoved ?? []).map(\.message.id))
        }
        return HistoryPage(ids: ids, historyID: decoded.historyId, nextPageToken: decoded.nextPageToken)
    }

    static func profileHistoryID(from data: Data) throws -> String {
        struct Response: Decodable { var historyId: String? }
        guard let id = (try? JSONDecoder().decode(Response.self, from: data))?.historyId else {
            throw GoogleFailure.decodingFailed
        }
        return id
    }

    static func message(from data: Data) throws -> GmailMessage {
        guard let resource = try? JSONDecoder().decode(GmailMessageResource.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return map(resource)
    }

    static func thread(from data: Data) -> [GmailMessage] {
        struct Response: Decodable { var messages: [GmailMessageResource]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return (decoded.messages ?? []).map(map)
    }

    static func labels(from data: Data) -> [GmailLabel] {
        struct Entry: Decodable {
            var id: String?
            var name: String?
            var type: String?
        }
        struct Response: Decodable { var labels: [Entry]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return (decoded.labels ?? [])
            .filter { $0.type == "user" }
            .compactMap { entry in
                guard let id = entry.id, let name = entry.name else { return nil }
                return GmailLabel(id: id, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func senderName(from raw: String) -> String {
        guard let bracket = raw.firstIndex(of: "<") else { return raw }
        let name = raw[raw.startIndex..<bracket].trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = name.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return cleaned.isEmpty ? raw : cleaned
    }

    private static let namedEntities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
    private static let longestEntity = 8

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semicolon = after.firstIndex(of: ";"),
               after.distance(from: after.startIndex, to: semicolon) <= longestEntity,
               let value = entity(String(after[..<semicolon])) {
                result += value
                rest = after[after.index(after: semicolon)...]
            } else {
                result += "&"
                rest = after
            }
        }
        return result + rest
    }

    private static func entity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[name]
    }

    static func emailDate(_ string: String) -> Date? {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(")"), let open = text.firstIndex(of: "(") {
            text = String(text[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static let dateFormats = [
        "EEE, d MMM yyyy HH:mm:ss Z",
        "d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss z",
        "EEE, d MMM yyyy HH:mm Z",
        "d MMM yyyy HH:mm Z",
    ]

    private static func internalDate(_ string: String?) -> Date? {
        guard let string, let milliseconds = Double(string) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }

    private static func map(_ resource: GmailMessageResource) -> GmailMessage {
        let headers = resource.payload?.headers ?? []
        func header(_ name: String) -> String? {
            headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }
        let fromRaw = header("From") ?? ""
        return GmailMessage(
            id: resource.id,
            threadID: resource.threadId ?? "",
            subject: header("Subject") ?? "",
            from: senderName(from: fromRaw),
            fromRaw: fromRaw,
            toRaw: header("To") ?? "",
            ccRaw: header("Cc") ?? "",
            snippet: decodeEntities(resource.snippet ?? ""),
            receivedAt: internalDate(resource.internalDate) ?? header("Date").flatMap(emailDate),
            labels: resource.labelIds ?? [],
            attachments: BodyParser.attachments(in: resource.payload?.parts ?? []),
            messageIDHeader: header("Message-ID") ?? "",
            likelyAttachments: (header("Content-Type") ?? "").lowercased().hasPrefix("multipart/mixed"))
    }
}
