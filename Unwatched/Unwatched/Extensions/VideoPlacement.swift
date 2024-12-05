//
//  VideoPlacement.swift
//  Unwatched
//

import UnwatchedShared

extension VideoPlacement {

    func description(defaultPlacement: String) -> String {
        switch self {
        case .inbox: return String(localized: "addToInbox")
        case .queueNext: return String(localized: "queueNext")
        case .queueLast: return String(localized: "queueLast")
        case .nothing: return String(localized: "doNothing")
        case .defaultPlacement: return String(localized: "defaultVideoPlacement \(defaultPlacement)")
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    var description: String {
        switch self {
        case .inbox: return String(localized: "addToInbox")
        case .queueNext: return String(localized: "queueNext")
        case .queueLast: return String(localized: "queueLast")
        case .nothing: return String(localized: "doNothing")
        case .defaultPlacement: return String(localized: "useDefault")
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    var shortDescription: String {
        switch self {
        case .inbox: return String(localized: "addToInboxShort")
        case .queueNext: return String(localized: "queueNext")
        case .queueLast: return String(localized: "queueLast")
        case .nothing: return String(localized: "doNothingShort")
        case .defaultPlacement: return String(localized: "useDefault")
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    public var systemName: String? {
        switch self {
        case .inbox: return Const.inboxTabEmptySF
        case .queueNext: return Const.queueTopSF
        case .queueLast: return Const.queueBottomSF
        case .nothing: return Const.clearSF
        case .defaultPlacement: return nil
        @unknown default:
            return "\(self.rawValue)"
        }
    }
}
