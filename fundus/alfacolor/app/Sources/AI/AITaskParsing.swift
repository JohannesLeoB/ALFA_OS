import Foundation

/// Reads the answers of the tasks. Junk around the expected form is ignored; a missing result is an error.
enum AITaskParsing {
    /// The opening line of a file block, and its closing line.
    static let fileOpening = "```datei:"
    static let blockClosing = "```"

    /// Reads the file blocks of an answer. Blocks with bad names, duplicate names or no closing line are dropped.
    static func code(_ text: String) throws -> AIProposal {
        var found: [(name: String, body: String)] = []
        var note: [String] = []
        var current: (name: String, lines: [String])?

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let block = current {
                if trimmed == blockClosing {
                    found.append((block.name, block.lines.joined(separator: "\n")))
                    current = nil
                } else {
                    current = (block.name, block.lines + [line])
                }
            } else if trimmed.hasPrefix(fileOpening) {
                current = (String(trimmed.dropFirst(fileOpening.count)).trimmingCharacters(in: .whitespaces), [])
            } else {
                note.append(line)
            }
        }
        // A block that never closes is cut off and dropped.

        var counts: [String: Int] = [:]
        for block in found {
            counts[block.name, default: 0] += 1
        }
        var files: [String: String] = [:]
        for block in found where isValidFileName(block.name) && counts[block.name] == 1 {
            files[block.name] = block.body
        }
        guard !files.isEmpty else {
            throw AIError.unusableAnswer("no file block with a usable name")
        }
        return .code(files: files, note: note.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A file name is one plain name: no empty text, no parent steps, no path separators.
    static func isValidFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("..") && !name.contains("/") && !name.contains("\\")
    }

    /// Reads the names from the JSON of the answer. Only known ids, valid names and first uses are kept.
    static func names(_ text: String, tokens: [TokenCandidate]) throws -> AIProposal {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let wire = try? JSONDecoder().decode(NamesWire.self, from: Data(text[start...end].utf8)) else {
            throw AIError.unusableAnswer("the names are not JSON")
        }
        let known = Set(tokens.map(\.id))
        var names: [String: String] = [:]
        var used: Set<String> = []
        for entry in wire.names where known.contains(entry.id) && names[entry.id] == nil {
            let name = entry.name.trimmingCharacters(in: .whitespaces)
            guard isValidTokenName(name), !used.contains(name) else { continue }
            names[entry.id] = name
            used.insert(name)
        }
        guard !names.isEmpty else {
            throw AIError.unusableAnswer("no valid name for a known token")
        }
        return .names(names)
    }

    /// A token name is not empty and has no dots or braces, as the naming rules of the workshop require.
    static func isValidTokenName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains(".") && !name.contains("{") && !name.contains("}")
    }

    /// The text of a plain answer, trimmed. An empty answer is an error.
    static func explanation(_ text: String) throws -> AIProposal {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIError.unusableAnswer("the explanation is empty")
        }
        return .text(trimmed)
    }
}

private struct NamesWire: Decodable {
    let names: [Entry]

    struct Entry: Decodable {
        let id: String
        let name: String
    }
}
