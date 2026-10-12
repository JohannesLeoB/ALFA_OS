import Mail
import ShellCore
import SwiftUI

struct MailLaneView: View {
    let lane: Lane
    @Environment(\.hostLive) private var live
    @Environment(\.appHost) private var host

    var body: some View {
        if live, let host {
            MailLaneContent(host: host, lane: lane)
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}

private struct MailLaneContent: View {
    let host: AppHost
    let lane: Lane

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { host.prepare() }
    }

    @ViewBuilder
    private var content: some View {
        switch host.phase {
        case .idle:
            word("mail.state.loading")
        case .failed(let description):
            VStack(alignment: .leading) {
                word("mail.state.failed")
                Text(verbatim: description)
            }
        case .ready(let assembly):
            switch lane {
            case .leading: MailAccountsPane(model: assembly.model)
            case .center: MailListPane(model: assembly.model)
            case .trailing: MailReadingPane(model: assembly.model)
            }
        }
    }
}
