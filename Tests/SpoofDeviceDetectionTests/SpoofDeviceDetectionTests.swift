import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
import VerIDCommonTypes
import SpoofDeviceDetectionCore
@testable import SpoofDeviceDetection

final class SpoofDeviceDetectionTests: XCTestCase {
    
    var spoofDetector: SpoofDeviceDetection!
    lazy var testImage: Image? = {
        guard let imageUrl = Bundle.module.url(forResource: "face_on_iPad_001", withExtension: "jpg", subdirectory: nil) else {
            return nil
        }
        guard let imageData = try? Data(contentsOf: imageUrl) else {
            return nil
        }
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            return nil
        }
        guard let image = Image(cgImage: cgImage, orientation: .up, depthData: nil) else {
            return nil
        }
        return image
    }()
    let testImageFaceRect = CGRect(x: 1020, y: 1420, width: 1070, height: 1350)
    
    override func setUpWithError() throws {
        super.setUp()
        HTTPStubs.setEnabled(true)
        HTTPStubs.removeAllStubs()
        self.spoofDetector = try self.createSpoofDeviceDetection()
    }
    
    override func tearDown() {
        super.tearDown()
        HTTPStubs.removeAllStubs()
        HTTPStubs.setEnabled(false)
    }
    
    func testDetectSpoofDevices() async throws {
        stub(condition: isPath("/detect_spoof_devices") && isMethodPOST()) { _ in
            do {
                guard let jsonURL = Bundle.module.url(forResource: "response", withExtension: "json") else {
                    throw NSError()
                }
                return HTTPStubsResponse(fileURL: jsonURL, statusCode: 200, headers: ["Content-Type": "application/json"])
            } catch {
                return HTTPStubsResponse(error: error)
            }
        }
        guard let image = self.testImage else {
            XCTFail()
            return
        }
        let spoofDevices = try await self.spoofDetector.detectSpoofDevicesInImage(image)
        XCTAssertEqual(spoofDevices.count, 1)
//        // Uncomment the following block to render the spoof device outline on to the original image and attach it to the test
//        guard let cgImage = image.toCGImage() else {
//            XCTFail()
//            return
//        }
//        let format = UIGraphicsImageRendererFormat()
//        format.scale = 1.0
//        let annotatedImage = UIGraphicsImageRenderer(size: image.size, format: format).image { context in
//            UIImage(cgImage: cgImage).draw(at: .zero)
//            context.cgContext.setStrokeColor(UIColor.green.cgColor)
//            context.cgContext.setLineWidth(4)
//            for spoofDevice in spoofDevices {
//                context.stroke(spoofDevice.boundingBox)
//            }
//        }
//        let attachment = XCTAttachment(image: annotatedImage)
//        attachment.lifetime = .keepAlways
//        self.add(attachment)
    }
    
    func testDetectSpoof() async throws {
        stub(condition: isPath("/detect_spoof_devices") && isMethodPOST()) { _ in
            do {
                guard let jsonURL = Bundle.module.url(forResource: "response", withExtension: "json") else {
                    throw NSError()
                }
                return HTTPStubsResponse(fileURL: jsonURL, statusCode: 200, headers: ["Content-Type": "application/json"])
            } catch {
                return HTTPStubsResponse(error: error)
            }
        }
        guard let image = self.testImage else {
            XCTFail()
            return
        }
        let isSpoof = try await self.spoofDetector.isSpoofInImage(image, regionOfInterest: self.testImageFaceRect)
        XCTAssertTrue(isSpoof)
    }
    
    func testDetectSpoofInCloud() async throws {
        HTTPStubs.setEnabled(false)
        guard let image = self.testImage else {
            XCTFail()
            return
        }
        let isSpoof = try await self.spoofDetector.isSpoofInImage(image, regionOfInterest: self.testImageFaceRect)
        XCTAssertTrue(isSpoof)
    }
    
    func testResizeImage() throws {
        guard let image = self.testImage else {
            XCTFail()
            return
        }
        let resizedImage = try self.spoofDetector.resizeImage(image)
        XCTAssertEqual(resizedImage.size.width, self.spoofDetector.imageLongerSideLength)
        XCTAssertEqual(resizedImage.size.height, self.spoofDetector.imageLongerSideLength)
    }
    
    private func createSpoofDeviceDetection() throws -> SpoofDeviceDetection {
        guard let configUrl = Bundle.module.url(forResource: "config", withExtension: "json") else {
            throw XCTSkip()
        }
        guard let configData = try? Data(contentsOf: configUrl) else {
            throw XCTSkip()
        }
        guard let config = try? JSONDecoder().decode(Config.self, from: configData) else {
            throw XCTSkip()
        }
        guard let url = URL(string: config.url) else {
            throw XCTSkip()
        }
        return SpoofDeviceDetection(apiKey: config.apiKey, url: url)
    }
}

fileprivate struct Config: Decodable {
    
    let apiKey: String
    let url: String
    
}
