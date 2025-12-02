//
//  PresentationDetent.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum PresentationDetentEncoding: Codable {
    case height(CGFloat)
    case none
    case medium
    case large

    func toPresentationDetent() -> PresentationDetent? {
        switch self {
        case .medium:
            return .medium
        case .large:
            return .large
        case .height(let height):
            return .height(height)
        default:
            return nil
        }
    }
}

extension PresentationDetent {
    func encode(_ playerControlHeight: CGFloat, _ maxSheetHeight: CGFloat) -> PresentationDetentEncoding? {
        switch self {
        case .medium:
            return .medium
        case .large:
            return .large
        case .height(playerControlHeight):
            return .height(playerControlHeight)
        case .height(maxSheetHeight):
            return .height(maxSheetHeight)
        default:
            return nil
        }
    }
}
