import Foundation

public struct SearchVocabulary: Sendable, Equatable {
    public struct CategoryEntry: Sendable, Equatable {
        public let name: String
        public let supergroup: String?
        public let synonyms: [String]

        public init(name: String, supergroup: String? = nil, synonyms: [String] = []) {
            self.name = name
            self.supergroup = supergroup
            self.synonyms = synonyms
        }
    }

    private let familyByWord: [String: Set<String>]
    private let tokensByCategory: [String: Set<String>]
    private let supergroupByCategory: [String: String]

    public static let empty = SearchVocabulary(categories: [])

    public init(categories: [CategoryEntry]) {
        var family: [String: Set<String>] = [:]
        var tokens: [String: Set<String>] = [:]
        var supergroups: [String: String] = [:]

        for entry in categories {
            let categoryKey = Self.normalize(entry.name)
            guard categoryKey.isEmpty == false else { continue }

            var words: Set<String> = [categoryKey]
            for raw in entry.synonyms {
                let word = Self.normalize(raw)
                if word.isEmpty == false { words.insert(word) }
            }

            var categoryTokens = words
            if let supergroup = entry.supergroup {
                let key = Self.normalize(supergroup)
                if key.isEmpty == false {
                    supergroups[categoryKey] = key
                    categoryTokens.insert(key)
                }
            }
            tokens[categoryKey] = categoryTokens

            for word in words {
                family[word, default: []].formUnion(words)
            }
        }

        self.familyByWord = family
        self.tokensByCategory = tokens
        self.supergroupByCategory = supergroups
    }

    public static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func expand(_ word: String) -> Set<String> {
        let key = Self.normalize(word)
        guard key.isEmpty == false else { return [] }
        return familyByWord[key] ?? [key]
    }

    public func tokens(forCategory category: String?) -> Set<String> {
        guard let category else { return [] }
        return tokensByCategory[Self.normalize(category)] ?? [Self.normalize(category)]
    }

    public func supergroup(forCategory category: String?) -> String? {
        guard let category else { return nil }
        return supergroupByCategory[Self.normalize(category)]
    }

    public var categoryCount: Int { tokensByCategory.count }

    public var supergroups: [String] { Set(supergroupByCategory.values).sorted() }
}

public enum TextDistance {
    public static func isWithin(_ maximum: Int, _ left: String, _ right: String) -> Bool {
        if left == right { return true }
        let a = Array(left), b = Array(right)
        if abs(a.count - b.count) > maximum { return false }
        if a.isEmpty { return b.count <= maximum }
        if b.isEmpty { return a.count <= maximum }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            var rowMinimum = current[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                rowMinimum = min(rowMinimum, current[j])
            }
            if rowMinimum > maximum { return false }
            swap(&previous, &current)
        }
        return previous[b.count] <= maximum
    }

    public static func tolerance(for word: String) -> Int {
        switch word.count {
        case 0...4:  return 0
        case 5...7:  return 1
        default:     return 2
        }
    }
}

public struct ArticleSearchIndex: Sendable {
    public static let scoreExact = 6
    public static let scorePrefix = 4
    public static let scoreInfix = 2
    public static let scoreTypo = 1

    private let articles: [ArtikelItem]
    private let postings: [String: [Int32]]
    private let sortedWords: [String]
    private let vocabulary: SearchVocabulary

    public init(articles: [ArtikelItem], vocabulary: SearchVocabulary = .empty) {
        self.articles = articles
        self.vocabulary = vocabulary

        var build: [String: [Int32]] = [:]
        build.reserveCapacity(articles.count * 4)
        for (offset, article) in articles.enumerated() {
            let position = Int32(offset)
            var seen = Set<String>(article.suchTokens)
            seen.formUnion(vocabulary.tokens(forCategory: article.kategorie))
            for word in seen { build[word, default: []].append(position) }
        }
        self.postings = build
        self.sortedWords = build.keys.sorted()
    }

    public var count: Int { articles.count }

    public var wordCount: Int { sortedWords.count }

    public func search(_ term: String) -> [ArtikelSuchergebnis] {
        let words = ArtikelItem.tokenize(term)
        guard words.isEmpty == false else {
            return articles.map { ArtikelSuchergebnis(artikel: $0, score: 0) }
        }

        var running: [Int32: Int]?
        for word in words {
            let scores = scoresForWord(word)
            if scores.isEmpty { return [] }
            if let previous = running {
                var merged: [Int32: Int] = [:]
                merged.reserveCapacity(min(previous.count, scores.count))
                for (position, value) in scores {
                    if let earlier = previous[position] { merged[position] = earlier + value }
                }
                if merged.isEmpty { return [] }
                running = merged
            } else {
                running = scores
            }
        }

        guard let final = running else { return [] }
        return final
            .map { ArtikelSuchergebnis(artikel: articles[Int($0.key)], score: $0.value) }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.artikel.articleNumber < $1.artikel.articleNumber
            }
    }

    private func scoresForWord(_ raw: String) -> [Int32: Int] {
        let family = vocabulary.expand(raw)
        var best: [Int32: Int] = [:]

        func add(_ word: String, _ score: Int) {
            guard let list = postings[word] else { return }
            for position in list where (best[position] ?? 0) < score { best[position] = score }
        }

        for word in family { add(word, Self.scoreExact) }
        for word in family {
            for candidate in prefixMatches(word) where candidate != word {
                add(candidate, Self.scorePrefix)
            }
        }
        if best.isEmpty {
            for word in family where word.count >= 4 {
                for candidate in sortedWords where candidate.contains(word) {
                    add(candidate, Self.scoreInfix)
                }
            }
        }
        if best.isEmpty {
            for word in family {
                let tolerance = TextDistance.tolerance(for: word)
                guard tolerance > 0 else { continue }
                for candidate in sortedWords
                where abs(candidate.count - word.count) <= tolerance
                    && TextDistance.isWithin(tolerance, word, candidate) {
                    add(candidate, Self.scoreTypo)
                }
            }
        }
        return best
    }

    private func prefixMatches(_ prefix: String) -> ArraySlice<String> {
        guard prefix.isEmpty == false else { return [] }
        var low = 0, high = sortedWords.count
        while low < high {
            let mid = (low + high) / 2
            if sortedWords[mid] < prefix { low = mid + 1 } else { high = mid }
        }
        var end = low
        while end < sortedWords.count, sortedWords[end].hasPrefix(prefix) { end += 1 }
        return sortedWords[low..<end]
    }
}
