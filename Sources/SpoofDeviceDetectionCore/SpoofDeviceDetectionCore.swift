//
//  SpoofDeviceDetectionCore.swift
//
//
//  Created by Jakub Dolejs on 17/06/2025.
//

import Foundation
import UIKit
import VerIDCommonTypes

open class SpoofDeviceDetectionCore: SpoofDetection {
    
    public init() throws {}
    
    public let imageLongerSideLength: CGFloat = 640
    
    /// Score above which `isSpoofInImage` reports a spoof.
    ///
    /// The comparison is inclusive: `SpoofDetection.isSpoofInImage` reports a spoof
    /// when the score is greater than or equal to this value, matching Android and
    /// the cloud.
    public var confidenceThreshold: Float = 0.5
    
    /// Stage 2 classifier.
    ///
    /// When `nil` only the device check runs. Variants that implement the dual
    /// liveness pipeline supply a classifier; the cloud variant does not.
    /// - Since: 1.1.0
    public var faceLivenessClassifier: (any FaceLivenessClassifier)?
    
    /// Score reported when the pipeline reaches no conclusion.
    ///
    /// Both stages signal inconclusive with `nil`: stage 1 when no device survives
    /// the policy, stage 2 when the crop is degenerate. An inconclusive pipeline
    /// resolves to **live**, and that is deliberate rather than incidental. The
    /// pipeline's only other exit is the stage 1 device check, which has already
    /// declined by the time this is reached, so there is no evidence of a spoof to
    /// report and the result must not be read as a rejection. The trade-off is
    /// real and is the same on Android: a spoof whose face box is degenerate reads
    /// live. The case is unreachable behind the capture gate, which requires the
    /// face to fill the oval before the countdown can complete.
    /// - Since: 1.1.0
    public static let inconclusiveScore: Float = 0

    public func detectSpoofInImage(_ image: Image, regionOfInterest: CGRect?) async throws -> Float {
        let spoofDevices = try await self.detectSpoofDevicesInImage(image)
        if let deviceScore = self.spoofScoreFromDeviceCheck(spoofDevices, imageSize: image.size, regionOfInterest: regionOfInterest) {
            return deviceScore
        }
        guard let classifier = self.faceLivenessClassifier, let region = regionOfInterest else {
            // No face region means no evidence either way. Reporting the
            // inconclusive score rather than scoring the whole frame keeps a
            // missing region from being read as a confident result.
            return Self.inconclusiveScore
        }
        guard let probability = try await classifier.spoofProbabilityInImage(image, regionOfInterest: region) else {
            // Stage 2 could not score the region, so the pipeline is inconclusive
            // and resolves to live. See `inconclusiveScore`.
            return Self.inconclusiveScore
        }
        return probability
    }
    
    /// Stage 1 policy: the score to report from the device detections, or `nil` to
    /// fall through to stage 2.
    ///
    /// The default implementation preserves the original behaviour, which is what
    /// the cloud variant relies on: keep only detections whose bounding box
    /// contains the face region, report the highest confidence among them, and
    /// always return a value so that stage 2 is never reached.
    ///
    /// Variants that implement the dual liveness pipeline override this to apply
    /// a device threshold, reject boxes covering most of the frame, accept a
    /// partially overlapping box, and return a hard `1.0`; returning `nil` when no
    /// device is found lets stage 2 run.
    /// - Since: 1.1.0
    open func spoofScoreFromDeviceCheck(_ spoofDevices: [DetectedSpoof], imageSize: CGSize, regionOfInterest: CGRect?) -> Float? {
        var spoofDevices = spoofDevices
        if let region = regionOfInterest {
            spoofDevices = spoofDevices.filter({ $0.boundingBox.contains(region) })
        }
        return spoofDevices.max(by: { $0.confidence < $1.confidence })?.confidence ?? 0
    }
    
    open func detectSpoofDevicesInImage(_ image: Image) async throws -> [DetectedSpoof] {
        fatalError("Method not implemented")
    }
    
    public final func createImageTransformForImageSize(_ imageSize: CGSize) -> CGAffineTransform {
        let aspectWidth = self.imageLongerSideLength / imageSize.width
        let aspectHeight = self.imageLongerSideLength / imageSize.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let scaledWidth = imageSize.width * aspectRatio
        let scaledHeight = imageSize.height * aspectRatio
        
        let x = (self.imageLongerSideLength - scaledWidth) / 2.0
        let y = (self.imageLongerSideLength - scaledHeight) / 2.0
        
        // Scale and then translate to center in square canvas
        return CGAffineTransform.identity
            .scaledBy(x: aspectRatio, y: aspectRatio)
            .translatedBy(x: x / aspectRatio, y: y / aspectRatio)
    }
}
