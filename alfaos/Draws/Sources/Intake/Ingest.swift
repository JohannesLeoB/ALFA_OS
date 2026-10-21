import Foundation

public func ingest(data: Data, name: String) async throws -> Ingested {
    guard !data.isEmpty else { throw Failure.empty }
    let kind = Kind.detect(data, name: name)
    var r = Ingested(kind: kind, name: (name as NSString).lastPathComponent, size: data.count)
    switch kind {
    case .pdf: try Pdf.read(data, &r)
    case .png, .jpeg, .heic, .gif, .webp: try Pict.read(data, &r)
    case .svg: r.text = Markup.svg(data)
    case .html: r.text = Markup.html(Decode.string(data))
    case .mustache: Braces.read(Decode.string(data), &r)
    case .csv: Csv.read(data, &r)
    case .xlsx: try Xlsx.read(data, &r)
    case .idml: try Idml.read(data, &r)
    case .dxf: Dxf.read(data, &r)
    case .dwg:
        r.note("dwg.binary")
        r.note("dwg.\(String(decoding: data.prefix(6), as: UTF8.self))")
    case .json:
        r.text = Decode.string(data)
        if (try? JSONSerialization.jsonObject(with: data)) == nil { r.note("json.invalid") }
    case .text: r.text = Decode.string(data)
    case .unknown: r.note("kind.unknown")
    }
    return r
}
