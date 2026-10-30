enum OAuthScope: String, CaseIterable, Sendable {
    case imap = "https://outlook.office.com/IMAP.AccessAsUser.All"
    case smtp = "https://outlook.office.com/SMTP.Send"
    case offlineAccess = "offline_access"
    case openid
    case profile
    case email
}
