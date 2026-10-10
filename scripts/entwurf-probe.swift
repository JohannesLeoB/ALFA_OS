// Renders a local HTML file in a web view without a window and writes a PNG.
// No window, no Dock icon, no focus. Use it to check HTML drafts unseen.
//
// Build:  swiftc -O scripts/entwurf-probe.swift -o <scratch>/probe
// Run:    <scratch>/probe page.html out.png 1400 900 light "<js action>" "<js report>"
// The action runs after load; the report expression is printed as JSON with page errors.
// CSS animations and transitions do not advance here: the probe turns transitions off
// and maps requestAnimationFrame to a timer. Motion needs a check by a person.
import AppKit
import WebKit

let a = CommandLine.arguments
guard a.count > 4 else { print("usage: probe page.html out.png width height [light|dark] [action] [report]"); exit(64) }
let url = URL(fileURLWithPath: a[1])
let outPNG = a[2]
let width = CGFloat(Double(a[3]) ?? 1400), height = CGFloat(Double(a[4]) ?? 900)
let scheme = a.count > 5 ? a[5] : "light"
let action = a.count > 6 ? a[6] : ""
let report = a.count > 7 ? a[7] : "''"

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.appearance = NSAppearance(named: scheme == "dark" ? .darkAqua : .aqua)

final class Probe: NSObject, WKNavigationDelegate {
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            w.evaluateJavaScript(action.isEmpty ? "0" : action) { _, e1 in
                if let e1 { print("ACTION-ERROR:", e1) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    let js = "JSON.stringify({errs:window.__errs,report:(()=>{try{return \(report)}catch(e){return 'REPORT-ERR '+e}})()})"
                    w.evaluateJavaScript(js) { r, e2 in
                        print(r ?? "nil", e2.map { "\($0)" } ?? "")
                        let c = WKSnapshotConfiguration()
                        c.rect = CGRect(x: 0, y: 0, width: width, height: height)
                        c.snapshotWidth = NSNumber(value: Double(width))
                        w.takeSnapshot(with: c) { img, _ in
                            if let img, let t = img.tiffRepresentation, let rep = NSBitmapImageRep(data: t),
                               let png = rep.representation(using: .png, properties: [:]) {
                                try? png.write(to: URL(fileURLWithPath: outPNG))
                            }
                            exit(0)
                        }
                    }
                }
            }
        }
    }
}

let setup = """
window.__errs=[];
window.addEventListener('error',e=>{window.__errs.push((e.message||'')+' @'+e.lineno+':'+e.colno)});
window.addEventListener('unhandledrejection',e=>{window.__errs.push('REJ '+e.reason)});
window.requestAnimationFrame=cb=>setTimeout(()=>cb(performance.now()),16);
document.addEventListener('DOMContentLoaded',()=>{const s=document.createElement('style');
s.textContent='*,*::before,*::after{transition:none!important;animation-duration:.001s!important;animation-delay:0s!important}';
document.head.appendChild(s)});
"""
let cfg = WKWebViewConfiguration()
let uc = WKUserContentController()
uc.addUserScript(WKUserScript(source: setup, injectionTime: .atDocumentStart, forMainFrameOnly: true))
cfg.userContentController = uc
let web = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height), configuration: cfg)
let probe = Probe()
web.navigationDelegate = probe
web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
DispatchQueue.main.asyncAfter(deadline: .now() + 25) { print("TIMEOUT"); exit(2) }
app.run()
