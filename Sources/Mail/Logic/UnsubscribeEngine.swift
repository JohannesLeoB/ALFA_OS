import Foundation

public struct ListUnsubscribe: Codable, Equatable, Sendable {
    public var mail: URL?
    public var web: URL?
    public var oneClick: Bool

    public var unsubscribes: Bool { oneClick || mail != nil }
}

public enum UnsubscribeEngine {
    static let headerName = "List-Unsubscribe"
    static let postName = "List-Unsubscribe-Post"
    static let oneClickBody = "List-Unsubscribe=One-Click"
    static let fallbackSubject = "unsubscribe"

    public static func parse(_ header: String?, post: String?) -> ListUnsubscribe? {
        guard let header else { return nil }
        var mail: URL?
        var web: URL?
        for link in links(header) {
            guard let url = URL(string: link), let scheme = url.scheme?.lowercased() else { continue }
            if scheme == "mailto", mail == nil, draft(url) != nil { mail = url }
            if scheme == "https" || scheme == "http", web == nil { web = url }
        }
        guard mail != nil || web != nil else { return nil }
        let asked = (post ?? "").filter { !$0.isWhitespace }.lowercased() == oneClickBody.lowercased()
        return ListUnsubscribe(mail: mail, web: web, oneClick: asked && web?.scheme?.lowercased() == "https")
    }

    static func parse(_ headers: [HeaderField]) -> ListUnsubscribe? {
        func value(_ name: String) -> String? { headers.first { $0.name.lowercased() == name.lowercased() }?.value }
        return parse(value(headerName), post: value(postName))
    }

    static func links(_ header: String) -> [String] {
        var result: [String] = []
        var rest = Substring(header)
        while let open = rest.firstIndex(of: "<"), let close = rest[open...].firstIndex(of: ">") {
            result.append(String(rest[rest.index(after: open)..<close].filter { !$0.isWhitespace }))
            rest = rest[rest.index(after: close)...]
        }
        return result
    }

    public static func draft(_ url: URL) -> Draft? {
        guard url.scheme?.lowercased() == "mailto",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let address = components.path.removingPercentEncoding ?? components.path
        guard AddressListParser.split(address).count == 1 else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name.lowercased() == name }?.value }
        let subject = value("subject").flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? fallbackSubject
        return Draft(to: address, subject: subject, body: value("body") ?? "")
    }

    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(oneClickBody.utf8)
        return request
    }
}
