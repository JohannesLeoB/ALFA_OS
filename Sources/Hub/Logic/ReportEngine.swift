import Foundation

enum ReportEngine {
    static func entry(inlet: Inlet.ID, event: ReportEvent, capability: Capability?, ok: Bool, at: Date,
                      kind: FailureKind? = nil, hint: String? = nil, original: Original? = nil) -> ReportEntry {
        ReportEntry(inlet: inlet, event: event, capability: capability, at: at, ok: ok, kind: kind, hint: hint, original: original)
    }

    static func failureEntry(inlet: Inlet.ID, event: ReportEvent, capability: Capability?, hint: Hint, at: Date) -> ReportEntry {
        entry(inlet: inlet, event: event, capability: capability, ok: false, at: at, kind: hint.kind ?? .rejected, hint: hint.text,
              original: hint.original ?? hint.detail.map { Original(provider: "unknown", text: $0) })
    }

    static func repeatsSuccess(ok: Bool, event: ReportEvent, capability: Capability?, in entries: [ReportEntry]) -> Bool {
        guard ok else { return false }
        return entries.first { $0.event == event && $0.capability == capability }?.ok == true
    }

    static func appended(_ entry: ReportEntry, to entries: [ReportEntry], limit: Int) -> [ReportEntry] {
        Array(([entry] + entries).prefix(limit))
    }
}
