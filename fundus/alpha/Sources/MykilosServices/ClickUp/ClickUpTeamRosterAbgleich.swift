import Foundation
import MykilosKit

public extension TeamRoster {
    static func sync(mitRealenMembers members: [ClickUpMember]) -> [TeamMember] {
        members.map { member in
            if let bekannt = alle.first(where: { $0.clickUpMemberID == member.id }) {
                return bekannt
            }
            let fallback = member.username.isEmpty ? "ID \(member.id)" : member.username
            return TeamMember(kuerzel: fallback, clickUpMemberID: member.id)
        }
    }
}
