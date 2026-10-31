import Foundation
import XCTest
@testable import Core

final class CoreTests: XCTestCase {
    func testInitialsFollowNameRules() {
        let cases = [("Anna Berg", "AB"), ("Anna", "A"), ("Anna von Berg", "AB"), ("An Ida Cruz", "IC"), ("  ", ""), ("élodie de la Cruz Jr.", "ÉC"), ("(Anna) Berg", "AB"), ("Anna Berg 42", "AB")]
        for (name, expected) in cases {
            XCTAssertEqual(Initials.from(name), expected)
        }
        XCTAssertEqual([Initials.avatar(code: "xy", name: "Anna Berg"), Initials.avatar(code: " ", name: "Anna Berg")], ["xy", "AB"])
    }

    func testCSVTableParsesQuotesBomAndTrimming() throws {
        let table = try CSVTable(data: "\u{FEFF}name, note\r\n a ,\"x, \"\"y\"\"\"\n\nb,c\n")
        XCTAssertEqual(table.headers, ["name", "note"])
        XCTAssertEqual(table.rows, [["name": "a", "note": "x, \"y\""], ["name": "b", "note": "c"]])
    }

    func testCSVTableRejectsBadShapes() {
        XCTAssertThrowsError(try CSVTable(data: "")) { XCTAssertEqual($0 as? CSVFailure, .empty) }
        XCTAssertThrowsError(try CSVTable(data: "a,b\n1,2\n3")) { XCTAssertEqual($0 as? CSVFailure, .inconsistentColumns(line: 3)) }
        XCTAssertThrowsError(try CSVTable(data: "a,a\n1,2")) { XCTAssertEqual($0 as? CSVFailure, .duplicateHeader("a")) }
    }

    func testCSVTableLenientPadsAndTruncates() throws {
        let table = try CSVTable(data: "a,b\n1\n1,2,3", lenient: true)
        XCTAssertEqual(table.rows, [["a": "1", "b": ""], ["a": "1", "b": "2"]])
    }

    func testRowAccessors() {
        let row = ["a": " 7 ", "b": "3.9", "c": "x"]
        XCTAssertEqual(row.string("a"), "7")
        XCTAssertEqual(row.string("missing"), "")
        XCTAssertEqual(row.int("a"), 7)
        XCTAssertEqual(row.int("b"), 3)
        XCTAssertEqual(row.int("c"), 0)
    }

    func testAddressSplit() {
        XCTAssertEqual(AddressSplitParser.parse("Musterstraße 12"), .init(street: "Musterstraße", houseNumber: "12"))
        XCTAssertEqual(AddressSplitParser.parse("12 Main Street"), .init(street: "Main Street", houseNumber: "12"))
        XCTAssertEqual(AddressSplitParser.parse("Hauptstr. 5a"), .init(street: "Hauptstr.", houseNumber: "5a"))
        XCTAssertEqual(AddressSplitParser.parse("Musterweg"), .init(street: "Musterweg", houseNumber: nil))
        XCTAssertEqual(AddressSplitParser.parse("  "), .init(street: "", houseNumber: nil))
        XCTAssertEqual(AddressSplitParser.parse("Hauptstr. 5, 2. Stock"), .init(street: "Hauptstr. 5, 2. Stock", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("Weg 10 - 12"), .init(street: "Weg 10 - 12", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("c/o Müller 5"), .init(street: "c/o Müller 5", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("Hauptstraße 12345"), .init(street: "Hauptstraße 12345", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("Hinterhaus Hauptstr. 5"), .init(street: "Hinterhaus Hauptstr. 5", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("Hof-Weg 3"), .init(street: "Hof-Weg", houseNumber: "3"))
        XCTAssertEqual(AddressSplitParser.parse("Weg – 12"), .init(street: "Weg – 12", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("Weg - 12"), .init(street: "Weg - 12", houseNumber: nil, unclear: true))
        XCTAssertEqual(AddressSplitParser.parse("/ 5"), .init(street: "/ 5", houseNumber: nil, unclear: true))
        XCTAssertTrue(AddressSplitParser.hasExtra("Weg 5 OG"))
        XCTAssertFalse(AddressSplitParser.hasExtra("Weg 5 og2"))
        XCTAssertFalse(AddressSplitParser.hasExtra("Hof-Weg 3"))
    }

    func testHouseNumberRules() {
        XCTAssertTrue(AddressSplitParser.isHouseNumber("12a"))
        XCTAssertTrue(AddressSplitParser.isHouseNumber("3-5"))
        XCTAssertFalse(AddressSplitParser.isHouseNumber("10115"))
        XCTAssertFalse(AddressSplitParser.isHouseNumber("5abcd"))
        XCTAssertFalse(AddressSplitParser.isHouseNumber("a5"))
        XCTAssertFalse(AddressSplitParser.isHouseNumber("5ä"))
    }

    func testNumberAndByteFormats() {
        XCTAssertEqual(Format.number(1_234_567), "1.234.567")
        XCTAssertEqual(Format.bytes(1_000_000), "1 MB")
        XCTAssertEqual(Format.bytes(3_000), "3 KB")
    }

    func testAttachmentSize() {
        XCTAssertEqual(Attachment(filename: "a", mimeType: "text/plain", data: Data(count: 512)).humanSize, "512 B")
        XCTAssertEqual(Attachment(filename: "a", mimeType: "text/plain", data: Data(count: 2048)).humanSize, "2 KB")
        XCTAssertEqual(Attachment(filename: "a", mimeType: "text/plain", data: Data(count: 1_572_864)).humanSize, "1.5 MB")
        XCTAssertEqual(Attachment(filename: "a.pdf", mimeType: "application/pdf", data: Data(count: 3)).id, "a.pdf-3")
    }

    func testAppIdentity() {
        XCTAssertEqual(AppIdentity.keychainPrefix, "com.johannesleoberger.alfaos.")
        XCTAssertEqual(Log.subsystem, AppIdentity.bundleID)
    }

    func testCompanyValuesDefaultToEmpty() {
        XCTAssertEqual(CompanyValues.valueOrEmpty("test.key.that.is.not.configured"), "")
    }

    func testPlaceholdersAreFilledInOnePassOverTheTemplate() {
        XCTAssertEqual(PlaceholderEngine.fill("{1} / {2}", ["{2}", "b"]), "{2} / b")
        XCTAssertEqual(PlaceholderEngine.fill("{2}{1}{2}", ["a", "{1}"]), "{1}a{1}")
        XCTAssertEqual(PlaceholderEngine.fill("{1}", ["{1}"]), "{1}")
    }

    func testPlaceholdersWithoutValueOrDigitsStayAsWritten() {
        XCTAssertEqual(PlaceholderEngine.fill("{3} {0} {} {x} {+1} { 1} {1", ["a", "b"]), "{3} {0} {} {x} {+1} { 1} {1")
        XCTAssertEqual(PlaceholderEngine.fill("}{1}{", ["a"]), "}a{")
        XCTAssertEqual(PlaceholderEngine.fill("", ["a"]), "")
        XCTAssertEqual(PlaceholderEngine.fill("Ünï {1}ß", ["é"]), "Ünï éß")
    }
}
