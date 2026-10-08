import Foundation

/// Times in the package: UTC, ISO 8601, rounded to milliseconds ("2026-10-08T12:34:56.789Z").
/// Own conversion instead of a formatter: fast, stateless and stable on a second write
/// (date to text to date to text gives the same text).
enum ISODate {
    private static let minMs: Int64 = -62_135_596_800_000   // 0001-01-01T00:00:00Z
    private static let maxMs: Int64 = 253_402_300_799_999   // 9999-12-31T23:59:59.999Z

    static func string(from date: Date) -> String? {
        let rounded = (date.timeIntervalSince1970 * 1000).rounded()
        guard rounded.isFinite, rounded >= Double(minMs), rounded <= Double(maxMs) else { return nil }
        let ms = Int64(rounded)
        var days = ms / 86_400_000
        var rest = ms % 86_400_000
        if rest < 0 { rest += 86_400_000; days -= 1 }
        let (y, m, d) = civil(fromDays: days)
        let h = rest / 3_600_000, mi = (rest / 60_000) % 60, s = (rest / 1000) % 60, f = rest % 1000
        return "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))T\(pad(h, 2)):\(pad(mi, 2)):\(pad(s, 2)).\(pad(f, 3))Z"
    }

    /// Reads "YYYY-MM-DDTHH:MM:SS", optionally with a fraction, then "Z" or "+HH:MM" / "-HH:MM".
    static func date(from text: String) -> Date? {
        let b = Array(text.utf8)
        var i = 0
        func digits(_ n: Int) -> Int64? {
            guard i + n <= b.count else { return nil }
            var v: Int64 = 0
            for k in i..<(i + n) { guard b[k] >= 48, b[k] <= 57 else { return nil }; v = v * 10 + Int64(b[k] - 48) }
            i += n
            return v
        }
        func eat(_ c: Character) -> Bool {
            guard i < b.count, b[i] == c.asciiValue else { return false }
            i += 1
            return true
        }
        guard let y = digits(4), eat("-"), let mo = digits(2), eat("-"), let d = digits(2), eat("T"),
              let h = digits(2), eat(":"), let mi = digits(2), eat(":"), let s = digits(2) else { return nil }
        var frac: Int64 = 0
        if eat(".") {
            var n = 0
            var scale: Int64 = 100
            while i < b.count, b[i] >= 48, b[i] <= 57 {
                if n < 3 { frac += Int64(b[i] - 48) * scale; scale /= 10 }
                n += 1; i += 1
            }
            guard n > 0 else { return nil }
        }
        var offsetMin: Int64 = 0
        if eat("Z") {
        } else if i < b.count, b[i] == 43 || b[i] == 45 {
            let sign: Int64 = b[i] == 43 ? 1 : -1
            i += 1
            guard let oh = digits(2), eat(":"), let om = digits(2) else { return nil }
            offsetMin = sign * (oh * 60 + om)
        } else { return nil }
        guard i == b.count, (1...12).contains(mo), (1...31).contains(d), h < 24, mi < 60, s < 60 else { return nil }
        guard d <= daysInMonth(year: y, month: mo) else { return nil }
        let days = days(fromCivil: y, mo, d)
        let ms = ((days * 86_400 + h * 3600 + mi * 60 + s - offsetMin * 60) * 1000) + frac
        return Date(timeIntervalSince1970: Double(ms) / 1000)
    }

    private static func pad(_ n: Int64, _ width: Int) -> String {
        let s = String(n)
        return String(repeating: "0", count: max(0, width - s.count)) + s
    }
    private static func daysInMonth(year y: Int64, month m: Int64) -> Int64 {
        switch m {
        case 2: (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
    // Days since 1970-01-01 and calendar date (algorithm by Howard Hinnant, proleptic Gregorian).
    private static func civil(fromDays days: Int64) -> (Int64, Int64, Int64) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
    private static func days(fromCivil year: Int64, _ m: Int64, _ d: Int64) -> Int64 {
        let y = year - (m <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}

/// Encoder and decoder of the package: JSON, UTF-8, sorted keys, indent 2, times as above.
enum PackageJSON {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, encoder in
            guard let s = ISODate.string(from: date) else {
                throw EncodingError.invalidValue(date, .init(codingPath: encoder.codingPath, debugDescription: String(localized: "package.reason.dateOutOfRange")))
            }
            var c = encoder.singleValueContainer()
            try c.encode(s)
        }
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = ISODate.date(from: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: String(localized: "package.reason.notISODate \(s)"))
            }
            return date
        }
        return d
    }
    /// Text with a final LF, as editors and Git expect it.
    static func data<T: Encodable>(_ value: T) throws -> Data {
        var data = try encoder().encode(value)
        data.append(0x0A)
        return data
    }
}
