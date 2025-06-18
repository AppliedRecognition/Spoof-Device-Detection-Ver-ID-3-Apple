# Spoof Device Detection

Detects spoof devices like screens in images

## Installation

### Swift Package Manager

1. Open your project in Xcode.
2. Select your project in the Project Navigator.
3. Click on the Package Dependencies tab.
4. Click the + icon and enter `https://github.com/AppliedRecognition/Spoof-Device-Detection-Apple.git` in the search box labelled "Search or Enter Package URL".
5. In the Dependency Rule drop-down select Up to Next Major Version and enter 1.0.0 in the adjacent text box.
6. Press the "Add Package" button.

## Usage

You will need an API key to use the face recognition in your project. The API key in tests is rate-limited and not suitable for production applications. Please [contact Applied Recognition](mailto:support@appliedrecognition.com) to obtain an API key.

### Sample code

Detect all spoof devices in an image.

```swift
import SpoofDeviceDetection

let uiImage: UIImage // The image in which to detect spoof devices

let apiKey: String // Your API key
let url: URL // Service URL

let spoofDeviceDetection = SpoofDeviceDetection(apiKey: apiKey, url: url)
guard let cgImage = uiImage.cgImage, let image = Image(cgImage: cgImage) else {
    fatalError("Image conversion failed")
}
Task {
    let spoofDevices = try await spoofDeviceDetection.detectSpoofDevicesInImage(image)
}
```

Find out whether a face in an image is a spoof.

```swift
import SpoofDeviceDetection
import VerIDCommonTypes

let uiImage: UIImage // The image in which to detect spoof devices
let face: Face // Face detected in the image

let apiKey: String // Your API key
let url: URL // Service URL

let spoofDeviceDetection = SpoofDeviceDetection(apiKey: apiKey, url: url)
guard let cgImage = uiImage.cgImage, let image = Image(cgImage: cgImage) else {
    fatalError("Image conversion failed")
}
Task {
    let isSpoof = try await spoofDeviceDetection.isSpoofInImage(image, regionOfInterest: face.bounds)
}
```
