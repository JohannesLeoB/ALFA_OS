import Mail
import ShellCore
import SwiftUI

struct MailStripMarks: View {
    let model: MailModel
    let lane: Lane
    let height: Double

    var body: some View {
        StripMarks(items: model.stripMarks(lane, height: height).map { mark in
            StripMarkItem(id: mark.id, face: mark.face, help: mark.help.key.map { word($0) } ?? Text(verbatim: mark.help.text),
                          selected: mark.selected, dot: mark.dot) { Task { await model.run(mark.run) } }
        })
    }
}
