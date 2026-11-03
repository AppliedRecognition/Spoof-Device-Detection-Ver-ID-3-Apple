//
//  SpoofDeviceDetectionCoreTests.swift
//
//
//  Created by Jakub Dolejs on 31/10/2025.
//

import XCTest
import UIKit
import CoreGraphics
import VerIDCommonTypes
@testable import SpoofDeviceDetectionCore

/// Device detection stub that leaves the stage 1 policy at its default, so the
/// shared default behaviour can be tested without a model.
private final class DefaultPolicyDeviceDetection: SpoofDeviceDetectionCore {
    var spoofDevices: [DetectedSpoof] = []
    override func detectSpoofDevicesInImage(_ image: Image) async throws -> [DetectedSpoof] {
        return self.spoofDevices
    }
}

/// Device detection stub whose stage 1 policy is driven by the test.
private final class StubPolicyDeviceDetection: SpoofDeviceDetectionCore {
    var spoofDevices: [DetectedSpoof] = []
    /// What `spoofScoreFromDeviceCheck` returns. `nil` means inconclusive, which
    /// is how the dual liveness pipeline signals that stage 2 should run.
    var deviceScore: Float?
    override func detectSpoofDevicesInImage(_ image: Image) async throws -> [DetectedSpoof] {
        return self.spoofDevices
    }
    override func spoofScoreFromDeviceCheck(_ spoofDevices: [DetectedSpoof], imageSize: CGSize, regionOfInterest: CGRect?) -> Float? {
        return self.deviceScore
    }
}

/// Stage 2 stub that records whether it was consulted.
private final class StubLivenessClassifier: FaceLivenessClassifier {
    /// What the classifier returns. `nil` means inconclusive, which is how a
    /// degenerate crop is reported.
    var probability: Float? = 0.5
    var callCount = 0
    func spoofProbabilityInImage(_ image: Image, regionOfInterest: CGRect) async throws -> Float? {
        self.callCount += 1
        return self.probability
    }
}

/// Stage 2 stub that fails outright, to separate an error from an inconclusive result.
private final class ThrowingLivenessClassifier: FaceLivenessClassifier {
    struct Failure: Error {}
    func spoofProbabilityInImage(_ image: Image, regionOfInterest: CGRect) async throws -> Float? {
        throw Failure()
    }
}

final class SpoofDeviceDetectionCoreTests: XCTestCase {

    private let imageSize = CGSize(width: 1000, height: 1000)
    private lazy var faceRegion = CGRect(x: 400, y: 400, width: 200, height: 200)

    private func makeImage() throws -> Image {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: Int(self.imageSize.width),
            height: Int(self.imageSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(UIColor.gray.cgColor)
        context.fill(CGRect(origin: .zero, size: self.imageSize))
        return try XCTUnwrap(Image(cgImage: try XCTUnwrap(context.makeImage())))
    }

    // MARK: - Default stage 1 policy
    //
    // The cloud variant relies on this behaviour, so it is pinned here. The dual
    // liveness policy that the on-device variant uses is tested in the internal
    // package, where it lives.

    func testDefaultPolicyReportsRawConfidenceForAContainingBox() async throws {
        let detector = try DefaultPolicyDeviceDetection()
        detector.spoofDevices = [DetectedSpoof(boundingBox: self.faceRegion, confidence: 0.85)]
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        // The raw confidence, not a hard 1.0.
        XCTAssertEqual(score, 0.85, accuracy: 1e-6)
    }

    func testDefaultPolicyIgnoresABoxThatOnlyIntersectsTheFace() async throws {
        let detector = try DefaultPolicyDeviceDetection()
        detector.spoofDevices = [DetectedSpoof(boundingBox: CGRect(x: 550, y: 550, width: 100, height: 100), confidence: 0.9)]
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, 0.0)
    }

    func testDefaultPolicyKeepsABoxThatContainsTheFace() async throws {
        let detector = try DefaultPolicyDeviceDetection()
        detector.spoofDevices = [DetectedSpoof(boundingBox: CGRect(x: 300, y: 300, width: 400, height: 400), confidence: 0.9)]
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, 0.9, accuracy: 1e-6)
    }

    func testDefaultPolicyDoesNotApplyADeviceThresholdOrAreaRejection() async throws {
        let detector = try DefaultPolicyDeviceDetection()
        // A low confidence box covering almost the whole frame still counts.
        detector.spoofDevices = [DetectedSpoof(boundingBox: CGRect(x: 20, y: 20, width: 960, height: 960), confidence: 0.2)]
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, 0.2, accuracy: 1e-6)
    }

    /// The default policy always returns a value, so stage 2 is never reached.
    func testDefaultPolicyNeverConsultsStageTwo() async throws {
        let detector = try DefaultPolicyDeviceDetection()
        detector.spoofDevices = [DetectedSpoof(boundingBox: self.faceRegion, confidence: 0.85)]
        let classifier = StubLivenessClassifier()
        detector.faceLivenessClassifier = classifier
        _ = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(classifier.callCount, 0)
    }

    // MARK: - Stage 2 fall-through

    func testStageTwoRunsWhenDeviceCheckIsInconclusive() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = nil
        let classifier = StubLivenessClassifier()
        classifier.probability = 0.42
        detector.faceLivenessClassifier = classifier
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, 0.42, accuracy: 1e-6)
        XCTAssertEqual(classifier.callCount, 1)
    }

    func testStageTwoIsSkippedWhenDeviceCheckIsConclusive() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = 1
        let classifier = StubLivenessClassifier()
        classifier.probability = 0.0
        detector.faceLivenessClassifier = classifier
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, 1.0)
        XCTAssertEqual(classifier.callCount, 0)
    }

    /// A missing face region means no evidence, which must not read as a spoof.
    func testNilRegionSkipsStageTwoAndReturnsZero() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = nil
        let classifier = StubLivenessClassifier()
        classifier.probability = 0.99
        detector.faceLivenessClassifier = classifier
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: nil)
        XCTAssertEqual(score, StubPolicyDeviceDetection.inconclusiveScore)
        XCTAssertEqual(classifier.callCount, 0)
    }

    func testNoClassifierReturnsZeroWhenDeviceCheckIsInconclusive() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = nil
        let score = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, StubPolicyDeviceDetection.inconclusiveScore)
    }

    // MARK: - An inconclusive Stage 2 resolves to live

    /// The contract that a degenerate crop is inconclusive rather than an error
    /// or a confident result, and that inconclusive resolves to **live**.
    ///
    /// The pipeline's only other exit is the stage 1 device check, which has
    /// already declined by the time Stage 2 runs, so an unscorable crop is no
    /// evidence of a spoof. Pinned here so the resolution cannot be changed to a
    /// rejection, or to a throw, without a test failing.
    func testInconclusiveStageTwoResolvesToLive() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = nil
        detector.confidenceThreshold = 0.95
        let classifier = StubLivenessClassifier()
        classifier.probability = nil
        detector.faceLivenessClassifier = classifier
        let image = try self.makeImage()

        let score = try await detector.detectSpoofInImage(image, regionOfInterest: self.faceRegion)
        XCTAssertEqual(score, StubPolicyDeviceDetection.inconclusiveScore)
        XCTAssertEqual(classifier.callCount, 1)

        // The resolution that matters: the pipeline reports live.
        let isSpoof = try await detector.isSpoofInImage(image, regionOfInterest: self.faceRegion)
        XCTAssertFalse(isSpoof)
    }

    /// A classifier that throws is still an error. Only `nil` is inconclusive.
    func testThrowingStageTwoStillPropagates() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = nil
        detector.faceLivenessClassifier = ThrowingLivenessClassifier()
        do {
            _ = try await detector.detectSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
            XCTFail("Expected the classifier's error to propagate")
        } catch {
            // Expected
        }
    }

    // MARK: - Threshold comparison

    /// `SpoofDetection.isSpoofInImage` uses `>=`, so a score exactly at the
    /// threshold is a spoof. Apple's shipped comparison was exclusive, which
    /// disagreed with Android and the cloud at exactly the threshold.
    func testThresholdComparisonIsInclusive() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.confidenceThreshold = 0.95
        detector.deviceScore = 0.95
        let image = try self.makeImage()
        let atThreshold = try await detector.isSpoofInImage(image, regionOfInterest: self.faceRegion)
        XCTAssertTrue(atThreshold)
        detector.deviceScore = 0.9499
        let belowThreshold = try await detector.isSpoofInImage(image, regionOfInterest: self.faceRegion)
        XCTAssertFalse(belowThreshold)
    }

    /// The specification states the rule on the Stage 2 score: spoof when the
    /// spoof probability is `>= 0.95`. Pinned separately because it is a
    /// different call site from the stage 1 score above.
    func testStageTwoScoreAtThresholdIsASpoof() async throws {
        let detector = try StubPolicyDeviceDetection()
        detector.deviceScore = nil
        detector.confidenceThreshold = 0.95
        let classifier = StubLivenessClassifier()
        classifier.probability = 0.95
        detector.faceLivenessClassifier = classifier
        let isSpoof = try await detector.isSpoofInImage(try self.makeImage(), regionOfInterest: self.faceRegion)
        XCTAssertTrue(isSpoof)
    }

    func testDefaultThresholdIsUnchanged() throws {
        XCTAssertEqual(try DefaultPolicyDeviceDetection().confidenceThreshold, 0.5, accuracy: 1e-6)
    }
}
