//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 17/06/2025.
//

import Foundation

public enum NetworkRequestError: LocalizedError {
    case requestFailed
    
    public var errorDescription: String? {
        switch self {
        case .requestFailed:
            return NSLocalizedString("Network request failed", comment: "")
        }
    }
}
