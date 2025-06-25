//
//  SpoofDeviceDetection.swift
//
//
//  Created by Jakub Dolejs on 17/06/2025.
//

import Foundation
import UIKit
import VerIDCommonTypes
import SpoofDeviceDetectionCore

public class SpoofDeviceDetection: SpoofDeviceDetectionCore {
    
    let url: URL
    let apiKey: String
    
    public init(apiKey: String, url: URL) {
        self.apiKey = apiKey
        self.url = url
        try! super.init()
    }
    
    public override func detectSpoofDevicesInImage(_ image: Image) async throws -> [DetectedSpoof] {
        let uiImage = try self.resizeImage(image)
        guard let png = uiImage.pngData() else {
            throw ImageProcessingError.pngError
        }
        let body = try self.createRequestBodyFromImageData(png)
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode < 400 else {
            throw NetworkRequestError.requestFailed
        }
        let spoofs = try JSONDecoder().decode([DetectedSpoof].self, from: data)
        return spoofs.map { spoof in
            let topLeft = self.mapPoint(spoof.boundingBox.origin, toOriginalImageSize: image.size)
            let bottomRight = self.mapPoint(CGPoint(x: spoof.boundingBox.maxX, y: spoof.boundingBox.maxY), toOriginalImageSize: image.size)
            let rect = CGRect(origin: topLeft, size: CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
            return DetectedSpoof(boundingBox: rect, confidence: spoof.confidence)
        }
    }
    
    func resizeImage(_ image: Image) throws -> UIImage {
        guard let cgImage = image.toCGImage() else {
            throw ImageProcessingError.cgImageConversionError
        }
        let uiImage = UIImage(cgImage: cgImage)
        let originalSize = uiImage.size
        let transform = self.createImageTransformForImageSize(originalSize)
        let scaledImageRect = CGRect(origin: .zero, size: originalSize).applying(transform)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let size = CGSize(width: self.imageLongerSideLength, height: self.imageLongerSideLength)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            uiImage.draw(in: scaledImageRect)
        }
    }
    
    private func createRequestBodyFromImageData(_ data: Data) throws -> Data {
        return try JSONEncoder().encode(RequestData(image: data))
    }
    
    private func mapPoint(_ point: CGPoint, toOriginalImageSize size: CGSize) -> CGPoint {
        let transform = self.createImageTransformForImageSize(size).inverted()
        return point.applying(transform)
    }
}

fileprivate struct RequestData: Encodable {
    let image: Data
}
