//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 06/06/2025.
//

import Foundation

public enum ImageProcessingError: LocalizedError {
    case cgImageConversionError, pngError
    
    public var errorDescription: String? {
        switch self {
        case .cgImageConversionError:
            return NSLocalizedString("Failed to convert image to CGImage", comment: "")
        case .pngError:
            return NSLocalizedString("Failed to convert image to PNG", comment: "")
        }
    }
}
