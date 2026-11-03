//
//  FaceLiveness.swift
//
//
//  Created by Jakub Dolejs on 31/10/2025.
//

import Foundation
import CoreGraphics
import VerIDCommonTypes

/// Second stage of the dual liveness pipeline: a passive texture classifier run
/// on the face region when the device check finds no spoof device.
///
/// The device check lives in `SpoofDeviceDetectionCore`. Stage 2 is a separate
/// model, so it is supplied by the package that owns the model rather than by
/// this package, and this protocol is the seam between them.
/// - Since: 2.0.0
public protocol FaceLivenessClassifier: AnyObject {

    /// Spoof probability for the face in the given region.
    ///
    /// Implementations are responsible for cropping the region. Use
    /// ``FaceLiveness/cropRect(forFaceRegionOfInterest:in:)`` so that the crop
    /// geometry cannot drift between implementations.
    /// - Parameters:
    ///   - image: Image containing the face
    ///   - regionOfInterest: Face bounding box in image pixel coordinates, origin top left
    /// - Returns: Probability between `0.0` and `1.0` that the face is a spoof, or
    ///   `nil` when the region cannot be scored.
    ///
    ///   `nil` means **inconclusive**, not spoof and not live. It is returned when
    ///   ``FaceLiveness/cropRect(forFaceRegionOfInterest:in:)`` reports a degenerate
    ///   crop. The caller resolves it, and it resolves to live; see
    ///   ``SpoofDeviceDetectionCore/detectSpoofInImage(_:regionOfInterest:)``.
    func spoofProbabilityInImage(_ image: Image, regionOfInterest: CGRect) async throws -> Float?
}

/// Constants that define the stage 2 liveness model contract.
///
/// These are shared between implementations so that a divergence is a deliberate
/// change rather than a silent drift. The values match the reference
/// implementation that the same model weights are served from in the cloud.
/// - Since: 2.0.0
public enum FaceLiveness {

    /// Side length of the model's square input.
    /// - Since: 2.0.0
    public static let inputSize = 224

    /// Side of the square crop as a multiple of the face region's longer side.
    ///
    /// A larger crop gives the classifier more of the context it needs to
    /// separate a real face from a face on a screen or a print, so this value is
    /// load bearing rather than cosmetic.
    /// - Since: 2.0.0
    public static let cropScale: CGFloat = 2.7

    /// ImageNet per-channel mean, applied after scaling pixel values to `0...1`.
    /// - Since: 2.0.0
    public static let mean: (red: Float, green: Float, blue: Float) = (0.485, 0.456, 0.406)

    /// ImageNet per-channel standard deviation.
    /// - Since: 2.0.0
    public static let std: (red: Float, green: Float, blue: Float) = (0.229, 0.224, 0.225)

    /// Shortest side, in pixels, that a stage 2 crop must have to be scored.
    ///
    /// A crop at or below this in either dimension is degenerate and inconclusive,
    /// not an error and not a full-frame score. The value matches Android's, so
    /// both platforms agree on *when* a crop is degenerate even though Android
    /// falls back to the full frame and Apple reports inconclusive.
    /// - Since: 1.1.0
    public static let minimumCropSide: CGFloat = 10

    /// Square crop centred on the face region, clamped to the image bounds.
    ///
    /// The crop is a square of side `max(width, height) * cropScale` centred on
    /// the region. Clamping can leave it non-square when the region is near an
    /// edge; callers stretch the result to ``inputSize`` without preserving
    /// aspect ratio, which is what the reference implementation does.
    ///
    /// The origin and the far edge are floored, matching Android's `toInt()`
    /// truncation, so the returned rectangle never has fractional bounds. This is
    /// deliberately not `CGRect.integral`, which expands outward: it would shift
    /// the crop by up to a pixel relative to Android and could push the far edge
    /// past the image bounds.
    /// - Parameters:
    ///   - region: Face bounding box in image pixel coordinates, origin top left
    ///   - imageSize: Size of the image the region refers to
    /// - Returns: Crop rectangle in the same coordinate space as `region`, or `nil`
    ///   when the crop would be ``minimumCropSide`` or less in either dimension.
    ///
    ///   `nil` means **inconclusive**: do not score the full frame instead.
    /// - Since: 2.0.0
    public static func cropRect(forFaceRegionOfInterest region: CGRect, in imageSize: CGSize) -> CGRect? {
        let side = max(region.width, region.height) * self.cropScale
        let centre = CGPoint(x: region.midX, y: region.midY)
        let left = max(0, (centre.x - side / 2).rounded(.down))
        let top = max(0, (centre.y - side / 2).rounded(.down))
        let right = min(imageSize.width, (centre.x + side / 2).rounded(.down))
        let bottom = min(imageSize.height, (centre.y + side / 2).rounded(.down))
        let width = right - left
        let height = bottom - top
        guard width > self.minimumCropSide, height > self.minimumCropSide else {
            return nil
        }
        return CGRect(x: left, y: top, width: width, height: height)
    }
}
