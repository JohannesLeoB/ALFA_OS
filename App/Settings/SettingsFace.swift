import Hub

struct SettingsFace: Identifiable {
    let id: String
    let title: String
    let meta: String
    let mark: String
    let detail: String
    let preview: String

    @MainActor
    init(id: String, readings: [IntegrationReading], appearance: Appearance, state: SettingsState) {
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
            meta = state.detailKey(of: section).map { appearance.string($0) } ?? ""
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
