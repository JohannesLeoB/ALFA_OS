#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MANIFEST = os.path.join(ROOT, "DESIGN", "MANIFEST.json")
WORK = os.path.join(ROOT, "dist", "icon-work")
OUTPUT = os.path.join(ROOT, "alfaos", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset")
SOURCE = "project/material/icons/app/B_A-Monogramm-komplett.svg"
SIZES = (16, 32, 128, 256, 512)
SCALES = (1, 2)

SWIFT = """import AppKit
import CryptoKit

func render(_ svg: String, _ px: Int) -> Data {
    guard let image = NSImage(contentsOfFile: svg) else { fatalError("svg not loaded") }
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)
    else { fatalError("no bitmap") }
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("no context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
    return png
}

func pixels(_ path: String) -> String {
    guard let data = FileManager.default.contents(atPath: path), let rep = NSBitmapImageRep(data: data) else {
        return "missing"
    }
    var raw = Data("\\(rep.pixelsWide)x\\(rep.pixelsHigh)".utf8)
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let c = rep.colorAt(x: x, y: y) else { return "unreadable" }
            for v in [c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent] {
                raw.append(UInt8((v * 255).rounded()))
            }
        }
    }
    return SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
}

let args = CommandLine.arguments
if args[1] == "render" {
    for item in args[4...] {
        let px = Int(item)!
        try render(args[2], px).write(to: URL(fileURLWithPath: args[3] + "/icon_\\(px).png"))
    }
} else {
    for path in args[2...] { print(pixels(path)) }
}
"""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def latest_master():
    with open(MANIFEST, "rb") as handle:
        entries = json.loads(handle.read().decode("utf-8"))["masters"]
    latest = [e for e in entries if e.get("rank") == "latest"]
    if len(latest) != 1:
        raise ValueError("DESIGN/MANIFEST.json: expected exactly one master with rank latest")
    return latest[0]


def read_source():
    entry = latest_master()
    path = os.path.join(ROOT, "DESIGN", entry["zip"])
    with open(path, "rb") as handle:
        data = handle.read()
    actual = sha256(data)
    if actual != entry["zipSha256"]:
        raise ValueError("checksum of %s is %s, manifest says %s: stop" % (entry["zip"], actual, entry["zipSha256"]))
    with zipfile.ZipFile(path) as archive:
        found = [n for n in archive.namelist() if n.endswith("/" + SOURCE)]
        if len(found) != 1:
            raise ValueError("%s: expected exactly one %s" % (entry["zip"], SOURCE))
        return archive.read(found[0])


def pixel_sizes():
    return sorted({size * scale for size in SIZES for scale in SCALES})


def render_all(target):
    os.makedirs(WORK, exist_ok=True)
    svg = os.path.join(WORK, "icon.svg")
    script = os.path.join(WORK, "icon.swift")
    with open(svg, "wb") as handle:
        handle.write(read_source())
    with open(script, "w", encoding="utf-8") as handle:
        handle.write(SWIFT)
    os.makedirs(target, exist_ok=True)
    run(script, "render", svg, target, *[str(px) for px in pixel_sizes()])


def run(script, *args):
    result = subprocess.run(["swift", script] + list(args), capture_output=True, text=True, cwd=WORK)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "swift failed")
    return result.stdout.split()


def contents():
    images = []
    for size in SIZES:
        for scale in SCALES:
            images.append({
                "filename": "icon_%d.png" % (size * scale),
                "idiom": "mac",
                "scale": "%dx" % scale,
                "size": "%dx%d" % (size, size),
            })
    return json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"


def write_contents(folder):
    with open(os.path.join(folder, "Contents.json"), "w", encoding="utf-8") as handle:
        handle.write(contents())


def main():
    parser = argparse.ArgumentParser(description="Render the master app icon into the asset catalog.")
    parser.add_argument("--check", action="store_true", help="exit 1 when the committed PNGs differ from a fresh render")
    args = parser.parse_args()
    try:
        if args.check:
            fresh = os.path.join(WORK, "fresh")
            shutil.rmtree(WORK, ignore_errors=True)
            render_all(fresh)
            names = ["icon_%d.png" % px for px in pixel_sizes()]
            problems = []
            for name in names:
                if not os.path.exists(os.path.join(OUTPUT, name)):
                    problems.append(name + " missing")
            if not problems:
                script = os.path.join(WORK, "icon.swift")
                old = run(script, "pixels", *[os.path.join(OUTPUT, n) for n in names])
                new = run(script, "pixels", *[os.path.join(fresh, n) for n in names])
                problems = [n + " differs" for n, a, b in zip(names, old, new) if a != b]
            path = os.path.join(OUTPUT, "Contents.json")
            if not os.path.exists(path) or open(path, encoding="utf-8").read() != contents():
                problems.append("Contents.json differs")
            if problems:
                print("icon_generate: " + "; ".join(problems), file=sys.stderr)
                return 1
            print("icon_generate: ok")
            return 0
        shutil.rmtree(WORK, ignore_errors=True)
        render_all(OUTPUT)
        write_contents(OUTPUT)
        print("icon_generate: wrote %d PNGs" % len(pixel_sizes()))
        return 0
    except (ValueError, RuntimeError, OSError) as error:
        print("icon_generate: %s" % error, file=sys.stderr)
        return 1
    finally:
        shutil.rmtree(WORK, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
