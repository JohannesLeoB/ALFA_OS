import Foundation
import Shell

extension AppSession {
    func announce(arrivals count: Int) async {
        let title = count == 1
            ? String(localized: String.LocalizationValue("shell.attention.newMail.one"))
            : String(format: String(localized: String.LocalizationValue("shell.attention.newMail.many")), String(count))
        await attention.announce(title: title)
    }
}
