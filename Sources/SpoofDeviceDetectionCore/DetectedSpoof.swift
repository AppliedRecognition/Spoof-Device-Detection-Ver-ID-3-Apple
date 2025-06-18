//
//  DetectedSpoof.swift
//
//
//  Created by Jakub Dolejs on 06/06/2025.
//

import UIKit

/// Represents a detected spoof device
/// - Since: 1.0.0
public struct DetectedSpoof: Codable {
    
    enum CodingKeys: String, CodingKey {
        case confidence, xmin, ymin, xmax, ymax
    }
    
    /// Bounding box of the detected spoof device
    /// - Since: 1.0.0
    public let boundingBox: CGRect
    /// Confidence in the detection (value between `0.0` and `1.0` where `1` means 100% confidence that
    /// the bounding box contains a spoof device
    /// - Since: 1.0.0
    public let confidence: Float
    
    public init(boundingBox: CGRect, confidence: Float) {
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.confidence = try container.decode(Float.self, forKey: .confidence)
        let xmin = try container.decode(CGFloat.self, forKey: .xmin)
        let ymin = try container.decode(CGFloat.self, forKey: .ymin)
        let xmax = try container.decode(CGFloat.self, forKey: .xmax)
        let ymax = try container.decode(CGFloat.self, forKey: .ymax)
        self.boundingBox = CGRect(x: xmin, y: ymin, width: xmax-xmin, height: ymax-ymin)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.confidence, forKey: .confidence)
        try container.encode(self.boundingBox.minX, forKey: .xmin)
        try container.encode(self.boundingBox.minY, forKey: .ymin)
        try container.encode(self.boundingBox.maxX, forKey: .xmax)
        try container.encode(self.boundingBox.maxY, forKey: .ymax)
    }
    
    /// Flip (mirror) the bounding box along its vertical axis
    ///
    /// May be useful if the detection is done on an image that's mirrored for display, e.g., capturing a selfie
    /// - Parameter imageSize: Size of the image in which the spoof device was detected
    /// - Returns: The detection with (mirrored) bounding box
    /// - Since: 1.0.0
    public func flipped(imageSize: CGSize) -> DetectedSpoof {
        let transform = CGAffineTransform(scaleX: -1, y: 1).concatenating(CGAffineTransform(translationX: imageSize.width, y: 0))
        return DetectedSpoof(boundingBox: self.boundingBox.applying(transform), confidence: self.confidence)
    }
}
