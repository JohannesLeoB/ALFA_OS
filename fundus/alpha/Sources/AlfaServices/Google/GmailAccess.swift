import Foundation

public enum GmailAccess {
    public static func client() -> GoogleGmailClient {
        GoogleGmailClient()
    }
}
