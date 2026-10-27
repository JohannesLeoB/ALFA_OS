import Hub

struct SettingsFace: Identifiable {
    let id: String
    let title: String
    let meta: String
    let mark: String
    let detail: String
    let preview: String

    init(id: String, readings: [IntegrationReading], appearance: Appearance) {
        self.id = id
        if let reading = readings.first(where: { $0.info.id == id }) {
            let name = appearance.string(reading.info.nameKey)
            title = name
            meta = appearance.string(reading.state.key)
            mark = String(name.prefix(1))
            detail = appearance.string(reading.info.useKey)
            preview = meta
        } else if let section = SettingsSection(rawValue: id) {
            let name = appearance.string(section.key)
            title = name
            meta = appearance.string(section.detailKey)
            mark = String(name.prefix(1))
            detail = meta
            preview = ""
        } else {
            title = id
            meta = ""
            mark = String(id.prefix(1))
            detail = ""
            preview = ""
        }
    }
}
