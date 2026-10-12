import Foundation

public enum PlanTypeFilter: String, CaseIterable, Sendable {
    case pdf, image

    public func matches(_ file: GoogleDriveFile) -> Bool {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch self {
        case .pdf:
            return ext == "pdf" || file.mimeType == "application/pdf"
        case .image:
            return ext != "pdf" && (file.mimeType.hasPrefix("image/")
                || ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "webp"].contains(ext))
        }
    }
}

public enum MaterialSort: String, CaseIterable, Sendable {
    case date, name
}

public enum MaterialSorter {
    public static func filtered(_ files: [GoogleDriveFile], query: String) -> [GoogleDriveFile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    public static func filtered(_ files: [GoogleDriveFile], type: PlanTypeFilter?) -> [GoogleDriveFile] {
        guard let type else { return files }
        return files.filter { type.matches($0) }
    }

    public static func sorted(_ files: [GoogleDriveFile], by sort: MaterialSort) -> [GoogleDriveFile] {
        switch sort {
        case .date:
            return files.sorted {
                ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
            }
        case .name:
            return files.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}
