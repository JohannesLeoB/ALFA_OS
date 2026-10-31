import Foundation

public enum FlowedEngine {
    public static func text(_ data: Data, contentType: String?) -> String {
        let type = RawMessageEngine.parameters(contentType ?? "")
        let text = MIME.string(from: data, charset: type.parameters["charset"])
        guard type.value == "text/plain", type.parameters["format"]?.lowercased() == "flowed" else { return text }
        return MIME.unflow(text, delSp: type.parameters["delsp"]?.lowercased() == "yes")
    }
}
