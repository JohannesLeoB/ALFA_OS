import Hub

enum ScopeEngine {
    static func scopes(for capabilities: Set<Capability>) -> [OAuthScope] {
        var scopes: [OAuthScope] = [.userinfoEmail, .userinfoProfile]
        if capabilities.contains(.mail) { scopes.append(.gmailModify) }
        if capabilities.contains(.calendar) { scopes += [.calendarReadonly, .calendarEvents] }
        if capabilities.contains(.contacts) { scopes += [.contacts, .directoryReadonly] }
        if capabilities.contains(.files) { scopes.append(.drive) }
        return scopes
    }
}
