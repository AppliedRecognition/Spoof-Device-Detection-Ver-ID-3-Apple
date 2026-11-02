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
    /// - Returns: Probability between `0.0` and `1.0` that the face is a spoof
    func spoofProbabilityInImage(_ image: Image, regionOfInterest: CGRect) async throws -> Float
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

    /// Square crop centred on the face region, clamped to the image bounds.
    ///
    /// The crop is a square of side `max(width, height) * cropScale` centred on
    /// the region. Clamping can leave it non-square when the region is near an
    /// edge; callers stretch the result to ``inputSize`` without preserving
    /// aspect ratio, which is what the reference implementation does.
    /// - Parameters:
    ///   - region: Face bounding box in image pixel coordinates, origin top left
    ///   - imageSize: Size of the image the region refers to
    /// - Returns: Crop rectangle in the same coordinate space as `region`
    /// - Since: 2.0.0
    public static func cropRect(forFaceRegionOfInterest region: CGRect, in imageSize: CGSize) -> CGRect {
        let side = max(region.width, region.height) * self.cropScale
        let centre = CGPoint(x: region.midX, y: region.midY)
        let minX = max(0, centre.x - side / 2)
        let minY = max(0, centre.y - side / 2)
        let maxX = min(imageSize.width, centre.x + side / 2)
        let maxY = min(imageSize.height, centre.y + side / 2)
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }
}
