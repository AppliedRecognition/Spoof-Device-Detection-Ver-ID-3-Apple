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
}
