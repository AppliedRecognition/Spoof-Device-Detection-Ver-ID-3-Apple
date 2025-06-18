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
    
    let imageLongerSideLength: CGFloat = 640
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
        let boundary = UUID().uuidString
        let body = self.createRequestBodyFromImageData(png, boundary: boundary)
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode < 400 else {
            throw NetworkRequestError.requestFailed
        }
        guard let spoofs = try JSONDecoder().decode([[DetectedSpoof]].self, from: data).first else {
            return []
        }
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
        let aspectWidth = self.imageLongerSideLength / originalSize.width
        let aspectHeight = self.imageLongerSideLength / originalSize.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let scaledImageSize = CGSize(
            width: originalSize.width * aspectRatio,
            height: originalSize.height * aspectRatio
        )
        
        // Calculate origin to center the image
        let x = (self.imageLongerSideLength - scaledImageSize.width) / 2.0
        let y = (self.imageLongerSideLength - scaledImageSize.height) / 2.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let size = CGSize(width: self.imageLongerSideLength, height: self.imageLongerSideLength)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            uiImage.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: scaledImageSize))
        }
    }
    
    private func createRequestBodyFromImageData(_ data: Data, boundary: String) -> Data {
        let fileName = "image.png"
        let mimeType = "image/png"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"confidence_threshold\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append(String(format: "%.04f\r\n", self.confidenceThreshold).data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
    
    private func mapPoint(_ point: CGPoint, toOriginalImageSize size: CGSize) -> CGPoint {
        let scale = self.imageLongerSideLength / max(size.width, size.height)
        let outWidth = round(size.width * scale)
        let outHeight = round(size.height * scale)
        let left = (self.imageLongerSideLength - outWidth) / 2
        let top = (self.imageLongerSideLength - outHeight) / 2
        let origX = (point.x - left) / scale
        let origY = (point.y - top) / scale
        return CGPoint(x: origX, y: origY)
    }
}
