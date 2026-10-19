import Foundation

extension MailModel {
    public func measureRow(_ id: String) async {
        guard let inlet = selectedInlet, let item = summaries.first(where: { $0.id == id }) else { return }
        if item.attachmentCount > 0, rowAttachments[id] == nil, let body = try? await engine.body(inlet, messageID: id) {
            rowAttachments[id] = body.attachments.map {
                MailAttachmentRow(id: $0.id, name: $0.filename, size: MailSize.label($0.sizeBytes))
            }
        }
        if !item.threadID.isEmpty, threadSizes[item.threadID] == nil,
           let messages = try? await engine.thread(inlet, messageID: id, threadID: item.threadID) {
            threadSizes[item.threadID] = messages.count
        }
    }
}
