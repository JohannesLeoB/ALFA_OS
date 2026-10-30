public enum FlowedEngine {
    public static func decode(_ text: String, contentType: String?) -> String {
        let header = (contentType ?? "").lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\"", with: "")
        guard header.contains("format=flowed") else { return text }
        return MIME.unflow(text, delSp: header.contains("delsp=yes"))
    }
}
