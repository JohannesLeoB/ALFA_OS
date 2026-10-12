import CoreGraphics
import Foundation

/// Geometry of a colour fan: blades of one width, riveted through one lower corner and opened into a half circle.
/// Every length is a fraction of the blade width, and the blade width follows from the size the fan may use.
/// Coordinates are points with y pointing down. The rivet is the origin of the pivot coordinates.
public struct FanGeometry: Equatable, Sendable {
    /// Blade length as a multiple of the blade width.
    public static let lengthPerWidth = 4.34
    /// Sweep radius as a multiple of the blade length. An open fan reaches this far from its rivet.
    public static let radiusPerLength = 1.03
    /// Corner radius of a blade as a fraction of its width.
    public static let cornerPerWidth = 0.21
    /// Radius of the rivet hole as a fraction of the blade width.
    public static let holeRadiusPerWidth = 0.0649
    /// Distance from the rivet to the left and the lower edge of its blade, as a fraction of the blade width.
    public static let insetPerWidth = 0.155
    /// Angle from the first blade to the last one when open, in degrees. 180 is a half circle.
    public static let defaultSpread = 180.0
    /// Share of the width and of the height of the view that the open fan may use.
    public static let sweepShareWidth = 0.4
    public static let sweepShareHeight = 0.54
    /// The fan keeps this share of the space it may use, so that the edges have room.
    public static let sweepScale = 0.8
    /// Gap between neighbouring blades, in degrees, at which every blade casts its full contact shadow.
    public static let contactFullDegrees = 6.0
    /// A tap within this many hole radii of the rivet counts as a tap on the rivet.
    public static let rivetReach = 2.0
    /// Shadow of the whole fan, as fractions of the blade width.
    public static let shadowOffsetPerWidth = 0.05
    public static let shadowRadiusPerWidth = 0.1
    /// Contact shadow of one blade on the blade below it, as fractions of the blade width.
    public static let contactOffsetPerWidth = 0.021
    public static let contactRadiusPerWidth = 0.039
    /// Gap between the tip of a blade and its code label, as a fraction of the blade width.
    public static let labelGapPerWidth = 0.13

    /// Number of blades. At least one.
    public let count: Int
    /// Width of one blade in points. The base unit of every length.
    public let bladeWidth: Double
    /// Angle from the first blade to the last one when open, in degrees.
    public let spread: Double

    public init(bladeWidth: Double, count: Int, spread: Double = FanGeometry.defaultSpread) {
        self.bladeWidth = max(0, bladeWidth)
        self.count = max(1, count)
        self.spread = spread
    }

    /// The fan that fits into `size`. The open fan spans at most the shares of width and height, and the blade width follows.
    public static func fitted(to size: CGSize, count: Int, spread: Double = FanGeometry.defaultSpread) -> FanGeometry {
        let reach = max(0, min(Double(size.width) * sweepShareWidth, Double(size.height) * sweepShareHeight) * sweepScale)
        return FanGeometry(bladeWidth: reach / radiusPerLength / lengthPerWidth, count: count, spread: spread)
    }

    // MARK: - Lengths

    public var bladeLength: Double { bladeWidth * FanGeometry.lengthPerWidth }
    public var sweepRadius: Double { bladeLength * FanGeometry.radiusPerLength }
    public var cornerRadius: Double { bladeWidth * FanGeometry.cornerPerWidth }
    public var holeRadius: Double { bladeWidth * FanGeometry.holeRadiusPerWidth }
    public var inset: Double { bladeWidth * FanGeometry.insetPerWidth }
    public var labelGap: Double { bladeWidth * FanGeometry.labelGapPerWidth }
    public var shadowOffset: Double { bladeWidth * FanGeometry.shadowOffsetPerWidth }
    public var shadowRadius: Double { bladeWidth * FanGeometry.shadowRadiusPerWidth }
    public var contactOffset: Double { bladeWidth * FanGeometry.contactOffsetPerWidth }
    public var contactRadius: Double { bladeWidth * FanGeometry.contactRadiusPerWidth }

    // MARK: - Placement

    /// One blade in pivot coordinates, before it turns: from the rivet it reaches up by the blade length less the inset,
    /// and down by the inset.
    public var bladeRect: CGRect {
        CGRect(x: CGFloat(-inset), y: CGFloat(inset - bladeLength), width: CGFloat(bladeWidth), height: CGFloat(bladeLength))
    }

    /// The rivet in the coordinates of one blade, measured from its top left corner. Every blade turns around this point.
    public var rivetInBlade: CGPoint {
        CGPoint(x: CGFloat(inset), y: CGFloat(bladeLength - inset))
    }

    /// Where the rivet sits in a view of `size` at `stage`. Shut, the stack is centred. From align on, the half circle is centred.
    public func pivot(for stage: FanStage, in size: CGSize) -> CGPoint {
        let width = Double(size.width), height = Double(size.height)
        switch stage {
        case .shut:
            return CGPoint(x: CGFloat(width / 2 - bladeWidth / 2 + inset), y: CGFloat(height / 2 + bladeLength / 2 - inset))
        case .align, .flat, .open:
            return CGPoint(x: CGFloat(width / 2), y: CGFloat(height / 2 + sweepRadius / 2))
        }
    }
}
