import Foundation

public enum BrotherQLRaster {
    public static let bytesProZeile = 162

    public static let dotsProZeile = bytesProZeile * 8

    public static let druckbareDots = 1164

    public static let rechterRandDots = 12 + 44

    public static let linkerRandDots = dotsProZeile - druckbareDots - rechterRandDots

    public static let invalidateBytes = 200

    public static func job(rowItems: [Data]) -> Data {
        var d = Data()
        d.append(contentsOf: [0x1B, 0x69, 0x61, 0x01])
        d.append(Data(repeating: 0x00, count: invalidateBytes))
        d.append(contentsOf: [0x1B, 0x40])
        d.append(contentsOf: [0x1B, 0x69, 0x61, 0x01])
        d.append(mediaUndQualitaet(rasterZeilen: rowItems.count))
        d.append(contentsOf: [0x1B, 0x69, 0x4D, 0x40])
        d.append(contentsOf: [0x1B, 0x69, 0x41, 0x01])
        d.append(contentsOf: [0x1B, 0x69, 0x4B, 0x08])
        d.append(contentsOf: [0x1B, 0x69, 0x64])
        d.append(contentsOf: leU16(35))
        for rowItem in rowItems {
            d.append(0x67); d.append(0x00); d.append(UInt8(rowItem.count))
            d.append(rowItem)
        }
        d.append(0x1A)
        return d
    }

    private static func mediaUndQualitaet(rasterZeilen: Int) -> Data {
        var d = Data()
        d.append(contentsOf: [0x1B, 0x69, 0x7A])

        d.append(0x80 | 0x02 | 0x04 | 0x08 | 0x40)
        d.append(0x0A)
        d.append(102)
        d.append(0x00)
        d.append(contentsOf: leU32(UInt32(rasterZeilen)))
        d.append(0x00)
        d.append(0x00)
        return d
    }

    public static func packeZeile(druckbareBits: [Bool]) -> Data {
        precondition(druckbareBits.count == druckbareDots,
                     "Zeile muss genau \(druckbareDots) Bits breit sein, war \(druckbareBits.count)")
        var bytes = [UInt8](repeating: 0, count: bytesProZeile)
        for (offset, bit) in druckbareBits.enumerated() where bit {
            let i = linkerRandDots + offset
            bytes[i / 8] |= (0x80 >> (i % 8))
        }
        return Data(bytes)
    }

    private static func leU16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
    private static func leU32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }
}
