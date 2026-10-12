import Foundation
import CoreGraphics
import ImageIO
import Accelerate

public enum PlanabgleichRechner {
    public static let dpi = 60
    public static let schwelleGrau: Float = 46
    static let zelle = 4
    static let minZellen = 2
    static let maxMm = 45.0

    public struct Fortschritt: Sendable { public let schritt: String; public let anteil: Double }

    public static func rechne(a aURL: URL, b bURL: URL,
                              fortschritt: (@Sendable (Fortschritt) -> Void)? = nil) throws -> PlanabgleichResultat {
        fortschritt?(.init(schritt: "Rastern A", anteil: 0.02))
        let satzA = try einlesen(aURL)
        fortschritt?(.init(schritt: "Rastern B", anteil: 0.15))
        let satzB = try einlesen(bURL)
        fortschritt?(.init(schritt: "Seiten zuordnen", anteil: 0.28))
        let (paare, bOhne) = zuordnen(satzA, satzB)
        let mmJePx = 25.4 / Double(dpi)

        var pages: [PlanSeitenPaar] = []
        var images: [Int: PlanSeitenBilder] = [:]
        for (i, paar) in paare.enumerated() {
            let aIdx = paar.a
            let aBild = satzA[aIdx]
            let basis = 0.3 + 0.65 * Double(i) / Double(max(1, paare.count))
            guard let bIdx = paar.b else {
                pages.append(PlanSeitenPaar(aSeite: aIdx + 1, bSeite: nil, naehe: paar.d,
                                             width: aBild.w, height: aBild.h, transform: nil, funde: [], groups: []))
                if let aCG = cgGrau(aBild) {
                    images[aIdx + 1] = PlanSeitenBilder(a: aCG, b: nil, bAusgerichtet: nil, diff: nil, scan2: nil)
                }
                continue
            }
            fortschritt?(.init(schritt: "Seite \(aIdx + 1): ausrichten", anteil: basis))
            let (bT, tf) = ausrichten(aBild, satzB[bIdx])
            fortschritt?(.init(schritt: "Seite \(aIdx + 1): Fundstellen", anteil: basis + 0.1))
            var (funde, nurA, nurB, w, h) = fundstellen(aBild, bT)
            for (n, _) in funde.enumerated() {
                funde[n].nr = n + 1
                funde[n].mmX = (Double(funde[n].x) * mmJePx * 10).rounded() / 10
                funde[n].mmY = (Double(funde[n].y) * mmJePx * 10).rounded() / 10
                funde[n].mmB = (Double(funde[n].b) * mmJePx * 10).rounded() / 10
                funde[n].mmH = (Double(funde[n].h) * mmJePx * 10).rounded() / 10
            }
            let groups = symbolgruppen(&funde, nurA: nurA, nurB: nurB, w: w, h: h)
            pages.append(PlanSeitenPaar(aSeite: aIdx + 1, bSeite: bIdx + 1, naehe: paar.d,
                                         width: w, height: h, transform: tf, funde: funde, groups: groups))
            if let aCG = cgGrau(aBild) {
                images[aIdx + 1] = PlanSeitenBilder(
                    a: aCG, b: cgGrau(satzB[bIdx]), bAusgerichtet: cgGrau(bT),
                    diff: diffebene(nurA: nurA, nurB: nurB, w: w, h: h),
                    scan2: scan2(aBild, bT, nurA: nurA, nurB: nurB, w: w, h: h))
            }
        }
        fortschritt?(.init(schritt: "Fertig", anteil: 1))
        var bSeitenBilder: [Int: CGImage] = [:]
        for (i, b) in satzB.enumerated() where cgGrau(b) != nil { bSeitenBilder[i + 1] = cgGrau(b) }
        let result = PlanabgleichErgebnis(
            dpi: dpi, mmJePx: mmJePx, schwelle: Int(schwelleGrau),
            aName: aURL.lastPathComponent, bName: bURL.lastPathComponent,
            aSeiten: satzA.count, bSeiten: satzB.count, pages: pages,
            bOhneGegenstueck: bOhne.map { $0 + 1 }, gerechnetAm: Date())
        return PlanabgleichResultat(result: result, images: images, bSeitenBilder: bSeitenBilder)
    }

    public static func einlesen(_ url: URL) throws -> [GrauBild] {
        if url.pathExtension.lowercased() == "pdf" {
            guard let doc = CGPDFDocument(url as CFURL) else { throw PlanabgleichFehler.dateiNichtLesbar(url) }
            guard doc.numberOfPages > 0 else { throw PlanabgleichFehler.keineSeiten(url) }
            return try (1...doc.numberOfPages).map { n in
                guard let page = doc.page(at: n) else { throw PlanabgleichFehler.keineSeiten(url) }
                return rasterePDFSeite(page)
            }
        }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw PlanabgleichFehler.dateiNichtLesbar(url)
        }
        return [grau(aus: img)]
    }

    static func rasterePDFSeite(_ page: CGPDFPage) -> GrauBild {
        let box = page.getBoxRect(.cropBox)
        let rot = page.rotationAngle
        let gedreht = rot == 90 || rot == 270
        let bw = gedreht ? box.height : box.width
        let bh = gedreht ? box.width : box.height
        let skala = CGFloat(dpi) / 72
        let w = max(1, Int((bw * skala).rounded())), h = max(1, Int((bh * skala).rounded()))
        var data = [UInt8](repeating: 255, count: w * h)
        data.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.interpolationQuality = .high
            ctx.setShouldAntialias(true)
            let t = page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: w, height: h), rotate: 0, preserveAspectRatio: true)
            ctx.concatenate(t)
            ctx.drawPDFPage(page)
        }
        return GrauBild(w: w, h: h, px: data.map(Float.init))
    }

    static func grau(aus img: CGImage) -> GrauBild {
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 255, count: w * h)
        data.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return GrauBild(w: w, h: h, px: data.map(Float.init))
    }

    static func signatur(_ g: GrauBild, n: Int = 160) -> [Float] {
        var v = [Float](repeating: 0, count: n * n)
        for y in 0..<n {
            let y0 = y * g.h / n, y1 = max(y0 + 1, (y + 1) * g.h / n)
            for x in 0..<n {
                let x0 = x * g.w / n, x1 = max(x0 + 1, (x + 1) * g.w / n)
                var s: Float = 0
                for yy in y0..<y1 { for xx in x0..<x1 { s += g.px[yy * g.w + xx] } }
                v[y * n + x] = s / Float((y1 - y0) * (x1 - x0))
            }
        }
        let m = v.reduce(0, +) / Float(v.count)
        let sd = sqrt(v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Float(v.count)) + 1e-6
        return v.map { ($0 - m) / sd }
    }

    struct Paar { let a: Int; let b: Int?; let d: Double? }

    static func zuordnen(_ satzA: [GrauBild], _ satzB: [GrauBild]) -> ([Paar], [Int]) {
        let sigA = satzA.map { signatur($0) }, sigB = satzB.map { signatur($0) }
        var vergeben = Set<Int>()
        var paare: [Paar] = []
        for (ai, sa) in sigA.enumerated() {
            var kosten: [(Double, Int)] = []
            for (bi, sb) in sigB.enumerated() where !vergeben.contains(bi) {
                var s: Float = 0
                for k in 0..<sa.count { s += abs(sa[k] - sb[k]) }
                kosten.append((Double(s / Float(sa.count)), bi))
            }
            kosten.sort { $0.0 < $1.0 }
            guard let erst = kosten.first else { paare.append(Paar(a: ai, b: nil, d: nil)); continue }
            let zweit = kosten.count > 1 ? kosten[1].0 : 99
            if erst.0 < 12 && erst.0 < zweit * 0.75 {
                vergeben.insert(erst.1); paare.append(Paar(a: ai, b: erst.1, d: (erst.0 * 100).rounded() / 100))
            } else {
                paare.append(Paar(a: ai, b: nil, d: (erst.0 * 100).rounded() / 100))
            }
        }
        return (paare, satzB.indices.filter { !vergeben.contains($0) })
    }

    static func log2n(_ n: Int) -> Int { var p = 0; while (1 << p) < n { p += 1 }; return p }

    static func hanning(_ n: Int) -> [Float] {
        guard n > 1 else { return [1] }
        return (0..<n).map { 0.5 - 0.5 * cos(2 * .pi * Float($0) / Float(n - 1)) }
    }

    static func vorbereiten(_ g: GrauBild, h: Int, w: Int, ph: Int, pw: Int) -> [Float] {
        var s: Float = 0
        for y in 0..<h { for x in 0..<w { s += g.px[y * g.w + x] } }
        let m = s / Float(h * w)
        let fy = hanning(h), fx = hanning(w)
        var out = [Float](repeating: 0, count: ph * pw)
        for y in 0..<h { for x in 0..<w { out[y * pw + x] = (g.px[y * g.w + x] - m) * fy[y] * fx[x] } }
        return out
    }

    static func phasenkorrelation(_ a: [Float], _ b: [Float], ph: Int, pw: Int) -> [Float] {
        let n = ph * pw
        let lw = log2n(pw), lh = log2n(ph)
        guard let setup = vDSP_create_fftsetup(vDSP_Length(max(lw, lh)), FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }
        var aR = a, aI = [Float](repeating: 0, count: n)
        var bR = b, bI = [Float](repeating: 0, count: n)
        var rR = [Float](repeating: 0, count: n), rI = [Float](repeating: 0, count: n)
        aR.withUnsafeMutableBufferPointer { ar in aI.withUnsafeMutableBufferPointer { ai in
        bR.withUnsafeMutableBufferPointer { br in bI.withUnsafeMutableBufferPointer { bi in
        rR.withUnsafeMutableBufferPointer { rr in rI.withUnsafeMutableBufferPointer { ri in
            var splitA = DSPSplitComplex(realp: ar.baseAddress!, imagp: ai.baseAddress!)
            var splitB = DSPSplitComplex(realp: br.baseAddress!, imagp: bi.baseAddress!)
            var splitR = DSPSplitComplex(realp: rr.baseAddress!, imagp: ri.baseAddress!)
            vDSP_fft2d_zip(setup, &splitA, 1, 0, vDSP_Length(lw), vDSP_Length(lh), FFTDirection(FFT_FORWARD))
            vDSP_fft2d_zip(setup, &splitB, 1, 0, vDSP_Length(lw), vDSP_Length(lh), FFTDirection(FFT_FORWARD))
            for k in 0..<n {
                let re = ar[k] * br[k] + ai[k] * bi[k]
                let im = ai[k] * br[k] - ar[k] * bi[k]
                let mag = sqrt(re * re + im * im) + 1e-9
                rr[k] = re / mag; ri[k] = im / mag
            }
            vDSP_fft2d_zip(setup, &splitR, 1, 0, vDSP_Length(lw), vDSP_Length(lh), FFTDirection(FFT_INVERSE))
        }}}}}}
        return rR
    }

    static func spitze(_ k: [Float], ph: Int, pw: Int) -> (dy: Int, dx: Int, guete: Double) {
        guard !k.isEmpty else { return (0, 0, 0) }
        var best = 0
        for i in 1..<k.count where k[i] > k[best] { best = i }
        let iy = best / pw, ix = best % pw
        let dy = iy <= ph / 2 ? iy : iy - ph
        let dx = ix <= pw / 2 ? ix : ix - pw
        var mabs: Float = 0
        for v in k { mabs += abs(v) }
        mabs /= Float(k.count)
        return (dy, dx, Double(k[best] / (mabs + 1e-9)))
    }

    static func versatz(_ a: GrauBild, _ b: GrauBild) -> (dy: Int, dx: Int, guete: Double) {
        let h = min(a.h, b.h), w = min(a.w, b.w)
        let ph = 1 << log2n(h), pw = 1 << log2n(w)
        let k = phasenkorrelation(vorbereiten(a, h: h, w: w, ph: ph, pw: pw),
                                  vorbereiten(b, h: h, w: w, ph: ph, pw: pw), ph: ph, pw: pw)
        let s = spitze(k, ph: ph, pw: pw)
        return (-s.dy, -s.dx, s.guete)
    }

    static func spektrum(_ g: GrauBild, h: Int, w: Int, ph: Int, pw: Int) -> [Float] {
        let n = ph * pw
        let lw = log2n(pw), lh = log2n(ph)
        guard let setup = vDSP_create_fftsetup(vDSP_Length(max(lw, lh)), FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }
        var re = vorbereiten(g, h: h, w: w, ph: ph, pw: pw), im = [Float](repeating: 0, count: n)
        re.withUnsafeMutableBufferPointer { r in im.withUnsafeMutableBufferPointer { i in
            var splitC = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
            vDSP_fft2d_zip(setup, &splitC, 1, 0, vDSP_Length(lw), vDSP_Length(lh), FFTDirection(FFT_FORWARD))
        }}
        var out = [Float](repeating: 0, count: n)
        for y in 0..<ph {
            let sy = (y + ph / 2) % ph
            for x in 0..<pw {
                let sx = (x + pw / 2) % pw
                let k = sy * pw + sx
                out[y * pw + x] = log1p(sqrt(re[k] * re[k] + im[k] * im[k]))
            }
        }
        return out
    }

    static func logpolar(_ m: [Float], h: Int, w: Int, nr: Int = 256, nt: Int = 360) -> (lp: [Float], basis: Double) {
        let cy = Double(h) / 2, cx = Double(w) / 2
        let rmax = min(cy, cx)
        let basis = log(rmax) / Double(nr)
        var out = [Float](repeating: 0, count: nr * nt)
        for ri in 0..<nr {
            let r = exp(Double(ri) * basis)
            for ti in 0..<nt {
                let t = Double.pi * Double(ti) / Double(nt)
                let y = min(h - 1, max(0, Int(cy + r * sin(t))))
                let x = min(w - 1, max(0, Int(cx + r * cos(t))))
                out[ri * nt + ti] = m[y * w + x]
            }
        }
        return (out, basis)
    }

    static func masstabUndWinkel(_ a: GrauBild, _ b: GrauBild) -> (skala: Double, grad: Double, guete: Double) {
        let h = min(a.h, b.h), w = min(a.w, b.w)
        let ph = 1 << log2n(h), pw = 1 << log2n(w)
        let (lpA, basis) = logpolar(spektrum(a, h: h, w: w, ph: ph, pw: pw), h: ph, w: pw)
        let (lpB, _) = logpolar(spektrum(b, h: h, w: w, ph: ph, pw: pw), h: ph, w: pw)
        let nr = 256, nt = 360
        let pr = 1 << log2n(nr), pt = 1 << log2n(nt)
        func feld(_ l: [Float]) -> [Float] {
            let m = l.reduce(0, +) / Float(l.count)
            let fy = hanning(nr), fx = hanning(nt)
            var out = [Float](repeating: 0, count: pr * pt)
            for y in 0..<nr { for x in 0..<nt { out[y * pt + x] = (l[y * nt + x] - m) * fy[y] * fx[x] } }
            return out
        }
        let k = phasenkorrelation(feld(lpA), feld(lpB), ph: pr, pw: pt)
        let s = spitze(k, ph: pr, pw: pt)
        return (exp(Double(s.dy) * basis), Double(s.dx) * (180.0 / Double(nt)), s.guete)
    }

    static func umformen(_ g: GrauBild, skala: Double, grad: Double, dy: Double = 0, dx: Double = 0) -> GrauBild {
        let w = g.w, h = g.h
        let cx = Double(w) / 2, cy = Double(h) / 2
        let a = grad * .pi / 180
        let c = cos(a) / skala, s = sin(a) / skala
        let m0 = c, m1 = s, m2 = cx - c * (cx - dx) - s * (cy - dy)
        let m3 = -s, m4 = c, m5 = cy + s * (cx - dx) - c * (cy - dy)
        var out = [Float](repeating: 255, count: w * h)
        for y in 0..<h {
            let fy = Double(y)
            for x in 0..<w {
                let fx = Double(x)
                let sx = m0 * fx + m1 * fy + m2
                let sy = m3 * fx + m4 * fy + m5
                let x0 = Int(floor(sx)), y0 = Int(floor(sy))
                guard x0 >= 0, y0 >= 0, x0 + 1 < w, y0 + 1 < h else { continue }
                let tx = Float(sx - Double(x0)), ty = Float(sy - Double(y0))
                let p00 = g.px[y0 * w + x0], p01 = g.px[y0 * w + x0 + 1]
                let p10 = g.px[(y0 + 1) * w + x0], p11 = g.px[(y0 + 1) * w + x0 + 1]
                out[y * w + x] = (p00 * (1 - tx) + p01 * tx) * (1 - ty) + (p10 * (1 - tx) + p11 * tx) * ty
            }
        }
        return GrauBild(w: w, h: h, px: out)
    }

    static func ausrichten(_ a: GrauBild, _ b: GrauBild, mitSkala: Bool = true) -> (GrauBild, PlanTransform) {
        var skala = 1.0, grad = 0.0, gLP = 0.0
        if mitSkala {
            let r = masstabUndWinkel(a, b)
            gLP = r.guete
            if r.skala > 0.5 && r.skala < 2.0 && abs(r.grad) < 45 && r.guete > 8 { skala = r.skala; grad = r.grad }
        }
        var bt = (skala != 1 || grad != 0) ? umformen(b, skala: skala, grad: grad) : b
        var (dy, dx, g1) = versatz(a, bt)
        bt = umformen(b, skala: skala, grad: grad, dy: Double(dy), dx: Double(dx))
        let (dy2, dx2, g2) = versatz(a, bt)
        if abs(dy2) + abs(dx2) > 0 {
            dy += dy2; dx += dx2
            bt = umformen(b, skala: skala, grad: grad, dy: Double(dy), dx: Double(dx))
            g1 = g2
        }
        return (bt, PlanTransform(skala: (skala * 1e5).rounded() / 1e5, grad: (grad * 1e3).rounded() / 1e3,
                                  dy: dy, dx: dx, guete: (g1 * 10).rounded() / 10, gueteLogPolar: (gLP * 10).rounded() / 10))
    }

    static func art(sa: Int, sb: Int) -> PlanFundArt {
        sb < Int(Double(sa) * 0.25) ? .weg : sa < Int(Double(sb) * 0.25) ? .neu : .geaendert
    }

    static func fundstellen(_ a: GrauBild, _ b: GrauBild) -> ([PlanFund], [Bool], [Bool], Int, Int) {
        let h = min(a.h, b.h), w = min(a.w, b.w)
        var match = [Bool](repeating: false, count: w * h)
        var nurA = match, nurB = match
        for y in 0..<h {
            for x in 0..<w {
                let pa = a.px[y * a.w + x], pb = b.px[y * b.w + x]
                if abs(pa - pb) > schwelleGrau {
                    let k = y * w + x
                    match[k] = true
                    if pa < pb { nurA[k] = true } else if pb < pa { nurB[k] = true }
                }
            }
        }
        let zy = h / zelle, zx = w / zelle
        var gz = [Int](repeating: 0, count: zy * zx), az = gz, bz = gz
        for y in 0..<zy * zelle {
            for x in 0..<zx * zelle {
                let k = y * w + x, z = (y / zelle) * zx + x / zelle
                if match[k] { gz[z] += 1 }
                if nurA[k] { az[z] += 1 }
                if nurB[k] { bz[z] += 1 }
            }
        }
        let dichte = max(2, (zelle * zelle) / 5)
        var gesehen = [Bool](repeating: false, count: zy * zx)
        func sum(_ f: [Int], _ y0: Int, _ y1: Int, _ x0: Int, _ x1: Int) -> Int {
            var s = 0; for y in y0..<y1 { for x in x0..<x1 { s += f[y * zx + x] } }; return s
        }
        var funde: [PlanFund] = []
        for y in 0..<zy {
            for x in 0..<zx {
                let z = y * zx + x
                guard gz[z] >= dichte, !gesehen[z] else { continue }
                var stapel = [(y, x)]; gesehen[z] = true
                var ys: [Int] = [], xs: [Int] = []
                while let (cy, cx) = stapel.popLast() {
                    ys.append(cy); xs.append(cx)
                    for (ny, nx) in [(cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)]
                    where ny >= 0 && ny < zy && nx >= 0 && nx < zx {
                        let nz = ny * zx + nx
                        if gz[nz] >= dichte && !gesehen[nz] { gesehen[nz] = true; stapel.append((ny, nx)) }
                    }
                }
                guard ys.count >= minZellen else { continue }
                let y0 = ys.min()!, y1 = ys.max()! + 1, x0 = xs.min()!, x1 = xs.max()! + 1
                let sa = sum(az, y0, y1, x0, x1), sb = sum(bz, y0, y1, x0, x1)
                funde.append(PlanFund(nr: 0, x: x0 * zelle, y: y0 * zelle, b: (x1 - x0) * zelle, h: (y1 - y0) * zelle,
                                      art: art(sa: sa, sb: sb), pixel: sum(gz, y0, y1, x0, x1), nurA: sa, nurB: sb,
                                      mmX: 0, mmY: 0, mmB: 0, mmH: 0))
            }
        }
        let grenze = Int(maxMm / (25.4 / Double(dpi)))
        func zaehl(_ m: [Bool], _ f: PlanFund) -> Int {
            var s = 0
            for y in f.y..<min(h, f.y + f.h) { for x in f.x..<min(w, f.x + f.b) where m[y * w + x] { s += 1 } }
            return s
        }
        var fertig: [PlanFund] = []
        var stapel = funde
        while let f = stapel.popLast() {
            if f.b <= grenze && f.h <= grenze { fertig.append(f); continue }
            let laengs = f.b >= f.h
            let n = laengs ? f.b : f.h
            var profil = [Int](repeating: 0, count: n)
            for y in f.y..<min(h, f.y + f.h) {
                for x in f.x..<min(w, f.x + f.b) where match[y * w + x] {
                    profil[laengs ? x - f.x : y - f.y] += 1
                }
            }
            let lo = n / 3, hi = max(n / 3 + 1, 2 * n / 3)
            var i = n / 2
            if hi > lo {
                i = lo
                for k in lo..<hi where profil[k] < profil[i] { i = k }
            }
            var t1 = f, t2 = f
            if laengs { t1.b = i; t2.x = f.x + i; t2.b = f.b - i } else { t1.h = i; t2.y = f.y + i; t2.h = f.h - i }
            for var t in [t1, t2] where t.b >= zelle && t.h >= zelle {
                let sa = zaehl(nurA, t), sb = zaehl(nurB, t)
                if sa + sb < 12 { continue }
                t.nurA = sa; t.nurB = sb; t.pixel = zaehl(match, t); t.art = art(sa: sa, sb: sb)
                stapel.append(t)
            }
        }
        fertig.sort { $0.pixel > $1.pixel }
        return (fertig, nurA, nurB, w, h)
    }

    static func symbolgruppen(_ funde: inout [PlanFund], nurA: [Bool], nurB: [Bool], w: Int, h: Int,
                              edge: Int = 28, schwelle: Float = 0.62) -> [PlanSymbolgruppe] {
        func stempel(_ f: PlanFund) -> [Float]? {
            guard f.b > 0, f.h > 0 else { return nil }
            var v = [Float](repeating: 0, count: edge * edge)
            for y in 0..<edge {
                let sy = min(f.h - 1, y * f.h / edge)
                for x in 0..<edge {
                    let sx = min(f.b - 1, x * f.b / edge)
                    let k = (f.y + sy) * w + f.x + sx
                    guard k < nurA.count else { continue }
                    let an: Bool
                    switch f.art { case .neu: an = nurB[k]; case .weg: an = nurA[k]; case .geaendert: an = nurA[k] || nurB[k] }
                    v[y * edge + x] = an ? 255 : 0
                }
            }
            let m = v.reduce(0, +) / Float(v.count)
            v = v.map { $0 - m }
            let n = sqrt(v.reduce(0) { $0 + $1 * $1 })
            return n > 1e-6 ? v.map { $0 / n } : nil
        }
        struct Klasse { var nr: Int; var patterns: [Float]; var mitglieder: [Int]; var b: Int; var h: Int; var art: PlanFundArt }
        var klassen: [Klasse] = []
        for i in funde.indices {
            guard let v = stempel(funde[i]) else { funde[i].group = 0; continue }
            var zugeordnet = false
            for k in klassen.indices {
                var dot: Float = 0
                for j in 0..<v.count { dot += v[j] * klassen[k].patterns[j] }
                if dot > schwelle
                    && abs(funde[i].b - klassen[k].b) < max(14, Int(Double(klassen[k].b) * 0.4))
                    && abs(funde[i].h - klassen[k].h) < max(14, Int(Double(klassen[k].h) * 0.4)) {
                    klassen[k].mitglieder.append(funde[i].nr); funde[i].group = klassen[k].nr; zugeordnet = true; break
                }
            }
            if !zugeordnet {
                klassen.append(Klasse(nr: klassen.count + 1, patterns: v, mitglieder: [funde[i].nr],
                                      b: funde[i].b, h: funde[i].h, art: funde[i].art))
                funde[i].group = klassen.count
            }
        }
        return klassen.filter { $0.mitglieder.count > 1 }
            .map { PlanSymbolgruppe(nr: $0.nr, count: $0.mitglieder.count, art: $0.art, b: $0.b, h: $0.h, mitglieder: $0.mitglieder) }
            .sorted { $0.count > $1.count }
    }

    public static func cgGrau(_ g: GrauBild) -> CGImage? {
        guard g.w > 0, g.h > 0, g.px.isEmpty == false else { return nil }
        let data = g.px.map { UInt8(max(0, min(255, $0.rounded()))) }
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(width: g.w, height: g.h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: g.w,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    static func cgRGBA(_ rgba: [UInt8], w: Int, h: Int) -> CGImage? {
        guard w > 0, h > 0, rgba.count >= w * h * 4 else { return nil }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    static let colorPath: (UInt8, UInt8, UInt8) = (214, 88, 20)
    static let colorNew: (UInt8, UInt8, UInt8) = (21, 92, 110)

    static func diffebene(nurA: [Bool], nurB: [Bool], w: Int, h: Int) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for k in 0..<(w * h) {
            if nurA[k] { rgba[k * 4] = colorPath.0; rgba[k * 4 + 1] = colorPath.1; rgba[k * 4 + 2] = colorPath.2; rgba[k * 4 + 3] = 255 } else if nurB[k] { rgba[k * 4] = colorNew.0; rgba[k * 4 + 1] = colorNew.1; rgba[k * 4 + 2] = colorNew.2; rgba[k * 4 + 3] = 255 }
        }
        return cgRGBA(rgba, w: w, h: h)
    }

    static func scan2(_ a: GrauBild, _ b: GrauBild, nurA: [Bool], nurB: [Bool], w: Int, h: Int) -> CGImage? {
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let k = y * w + x
                let basis = min(a.px[y * a.w + x], b.px[y * b.w + x])
                let g = UInt8(max(0, min(255, (255 - (255 - basis) * 0.22).rounded())))
                var (r, gg, bb) = (g, g, g)
                if nurA[k] { (r, gg, bb) = colorPath } else if nurB[k] { (r, gg, bb) = colorNew }
                rgba[k * 4] = r; rgba[k * 4 + 1] = gg; rgba[k * 4 + 2] = bb; rgba[k * 4 + 3] = 255
            }
        }
        return cgRGBA(rgba, w: w, h: h)
    }

    public static func csv(_ e: PlanabgleichErgebnis) -> String {
        var z = ["seiteA;seiteB;nr;art;x_mm;y_mm;breite_mm;hoehe_mm;pixel;gruppe"]
        for s in e.pages {
            for f in s.funde {
                z.append("\(s.aSeite);\(s.bSeite.map(String.init) ?? "");\(f.nr);\(f.art.title);\(f.mmX);\(f.mmY);\(f.mmB);\(f.mmH);\(f.pixel);\(f.group)")
            }
        }
        return z.joined(separator: "\n")
    }
}
