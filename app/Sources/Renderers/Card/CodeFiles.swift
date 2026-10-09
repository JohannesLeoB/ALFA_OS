/// The order in which the files of a code card are listed: markup first, then styles, scripts and Swift.
public enum CodeFiles {
    public static func ordered(_ names: [String]) -> [String] {
        names.sorted { (rank($0), $0) < (rank($1), $1) }
    }

    static func rank(_ fileName: String) -> Int {
        switch FileExtension.lowercased(fileName) {
        case "html", "htm": 0
        case "css": 1
        case "js", "jsx", "mjs", "ts", "tsx": 2
        case "swift": 3
        default: 4
        }
    }
}
