import Assist
import Foundation

public enum Live {
    public static func media(_ attachments: [Attachment]) async -> [Media] {
        var out: [Media] = []
        for item in attachments {
            let ready = await Prepare.attachment(item)
            let plain = ready.mediaType == Attachment.text
            guard ready.supported, !plain || !ready.note.isEmpty else { continue }
            out.append(Media(label: "Attachment \(ready.name), role: \(ready.role.rawValue)", mediaType: ready.mediaType,
                             data: plain ? Data() : ready.data, note: ready.note))
        }
        return out
    }
}
