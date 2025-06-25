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
    public var confidenceThreshold: Float = 0.5
    
    public func detectSpoofInImage(_ image: Image, regionOfInterest: CGRect?) async throws -> Float {
        var spoofDevices = try await self.detectSpoofDevicesInImage(image)
        if let roi = regionOfInterest {
            spoofDevices = spoofDevices.filter({ $0.boundingBox.contains(roi) })
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
