import Foundation
import ALFAcolorCore
import Geometry
import Document
import BoardModel

/// Times the model work behind the canvas. The numbers are for the work of one frame or one event,
/// without the drawing of the view. The view is measured on screen with Instruments (see `Signpost`).
public enum Measurement {
    /// The canvas of the measurements, in points (a window on a 14 inch laptop).
    public static let canvas = CanvasSize(width: 1400, height: 860)
    /// Snap tolerance in screen points.
    public static let snapTolerance = 4.0
    /// Height of a frame band in board points, as the view uses it for hit tests.
    public static let bandHeight = 28.0

    /// Times in milliseconds over several samples.
    public struct Timing: Equatable, Sendable {
        public let samples: Int
        public let medianMs: Double
        public let worstMs: Double

        init(_ values: [Double]) {
            let sorted = values.sorted()
            samples = sorted.count
            medianMs = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
            worstMs = sorted.last ?? 0
        }

        /// Frames per second that the model work alone allows (1000 divided by the median). Not the view.
        public var framesPerSecond: Double { medianMs > 0 ? 1000 / medianMs : .infinity }
    }

    /// What one frame of a pan or a zoom has to decide: how many items are drawn, and how long that takes.
    public struct DrawLoad: Equatable, Sendable {
        public let itemsTotal: Int
        public let drawnMedian: Int
        public let drawnWorst: Int
        public let timing: Timing
    }

    /// A drag: the time to index the other items once at the start, and the time for each step of the snap.
    public struct DragLoad: Equatable, Sendable {
        public let itemsIndexed: Int
        public let indexMs: Double
        public let snap: Timing
    }

    /// Saving and opening the package in a temporary folder, with a check that the document comes back equal.
    public struct DocumentLoad: Equatable, Sendable {
        public let writeMs: Double
        public let readMs: Double
        public let imagesWritten: Int
        public let roundTripEqual: Bool
        public let readClean: Bool
    }

    // MARK: Pan and zoom

    /// Pans the view across the board at one zoom. Each step decides what to draw.
    public static func pan(in space: Space, zoom: Double, steps: Int = 60) -> DrawLoad {
        let box = Visibility.bounds(in: space) ?? Rect(x: 0, y: 0, w: 1, h: 1)
        let visibleWidth = canvas.width / zoom
        let travel = max(box.w - visibleWidth, 0)
        return drawLoad(in: space, steps: steps) { step in
            Viewport(zoom: zoom, offsetX: box.x + travel * Double(step) / Double(steps), offsetY: box.y)
        }
    }

    /// Zooms in place from one zoom to another, geometrically, at the top left of the board.
    public static func zoom(in space: Space, from start: Double, to end: Double, steps: Int = 60) -> DrawLoad {
        let box = Visibility.bounds(in: space) ?? Rect(x: 0, y: 0, w: 1, h: 1)
        let ratio = end / start
        return drawLoad(in: space, steps: steps) { step in
            let zoom = start * pow(ratio, Double(step) / Double(steps))
            return Viewport(zoom: zoom, offsetX: box.x, offsetY: box.y)
        }
    }

    private static func drawLoad(in space: Space, steps: Int, view: (Int) -> Viewport) -> DrawLoad {
        var times: [Double] = []
        var counts: [Int] = []
        for step in 0...max(steps, 1) {
            let viewport = view(step)
            let clock = ContinuousClock()
            var drawn: [Item] = []
            let elapsed = clock.measure {
                drawn = Signpost.interval("Draw list") {
                    Visibility.drawn(in: space, viewport: viewport, canvas: canvas)
                }
            }
            times.append(milliseconds(elapsed))
            counts.append(drawn.count)
        }
        let sortedCounts = counts.sorted()
        return DrawLoad(itemsTotal: space.items.count,
                        drawnMedian: sortedCounts[sortedCounts.count / 2],
                        drawnWorst: sortedCounts.last ?? 0,
                        timing: Timing(times))
    }

    // MARK: Drag and snap

    /// Drags one rectangle across the board. The other visible items are indexed once, as at the start of a drag;
    /// each step then snaps the rectangle against that index.
    public static func drag(in space: Space, steps: Int = 60) -> DragLoad {
        let box = Visibility.bounds(in: space) ?? Rect(x: 0, y: 0, w: 1, h: 1)
        let moving = Rect(x: box.x, y: box.y, w: 120, h: 90)
        let others = space.items.filter { !$0.hidden }.map(\.rect)
        let stops = [4.0, 8, 16, 24, 48].enumerated().map { SpacingStop(name: "space.\($0.offset)", value: $0.element) }
        let clock = ContinuousClock()
        var targets = SnapTargets()
        let indexing = clock.measure {
            targets = SnapTargets(gridStep: 8, rects: others, spacing: stops)
        }
        var times: [Double] = []
        for step in 0...max(steps, 1) {
            let x = box.x + (box.w - moving.w) * Double(step) / Double(max(steps, 1))
            let y = box.y + (box.h - moving.h) * 0.5 + 3 * sin(Double(step))
            let rect = Rect(x: x + 1.5, y: y, w: moving.w, h: moving.h)
            let elapsed = clock.measure {
                _ = Signpost.interval("Snap step") {
                    Snapper.snap(rect, motion: .move, targets: targets, tolerance: snapTolerance, zoom: 1)
                }
            }
            times.append(milliseconds(elapsed))
        }
        return DragLoad(itemsIndexed: others.count, indexMs: milliseconds(indexing), snap: Timing(times))
    }

    // MARK: Hit tests

    /// Hit tests at points inside the view, against the items that the view draws there.
    public static func hitTests(in space: Space, viewport: Viewport, points: Int = 200) -> Timing {
        let drawn = Visibility.drawn(in: space, viewport: viewport, canvas: canvas)
        var random = SeededRandom(seed: 7)
        var times: [Double] = []
        let clock = ContinuousClock()
        for _ in 0..<max(points, 1) {
            let x = random.fraction(of: canvas.width), y = random.fraction(of: canvas.height)
            let elapsed = clock.measure {
                _ = Signpost.interval("Hit test") {
                    HitTest.item(atX: x, y: y, among: drawn, zoom: viewport.zoom, bandHeight: bandHeight)
                }
            }
            times.append(milliseconds(elapsed))
        }
        return Timing(times)
    }

    // MARK: Code cards

    /// How many code cards lie on the visible part of the canvas, and how many there are. Only those are live.
    public static func codeCardsOnScreen(in space: Space, viewport: Viewport) -> (onScreen: Int, total: Int) {
        let cards = space.items.filter { item in
            if case .code = item.content { return true }
            return false
        }
        let visible = cards.filter { Visibility.isOnScreen($0.rect, viewport: viewport, canvas: canvas) }
        return (visible.count, cards.count)
    }

    // MARK: Saving and opening

    /// Writes the document to a temporary package, reads it back, and removes the folder again.
    public static func documentRoundTrip(_ document: ALFAcolorDocument) throws -> DocumentLoad {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "alfacolor-perf-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Load.alfacolor", directoryHint: .isDirectory)
        let clock = ContinuousClock()
        var written: DocumentPackage.WriteReport?
        let writing = try clock.measure {
            written = try Signpost.interval("Save package") {
                try DocumentPackage.write(document, to: url, appVersion: "performance")
            }
        }
        var read: DocumentReadResult?
        let reading = try clock.measure {
            read = try Signpost.interval("Open package") {
                try DocumentPackage.read(from: url)
            }
        }
        return DocumentLoad(writeMs: milliseconds(writing), readMs: milliseconds(reading),
                            imagesWritten: written?.assetsWritten ?? 0,
                            roundTripEqual: read?.document == document,
                            readClean: read?.report.isClean ?? false)
    }

    // MARK: Memory

    /// The largest resident size of this process so far, in megabytes. It only grows during a run.
    public static func peakMegabytes() -> Double {
        var usage = rusage()
        _ = getrusage(RUSAGE_SELF, &usage)
        // On macOS ru_maxrss is in bytes.
        return Double(usage.ru_maxrss) / 1_048_576
    }

    static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
    }
}
