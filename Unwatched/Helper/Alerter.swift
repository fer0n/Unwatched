//
//  Alerter.swift
//  Unwatched
//

import Foundation
import SwiftUI

@Observable
final class Alerter {
    var alert: Alert? {
        didSet { isShowingAlert = alert != nil }
    }
    var isShowingAlert = false

    func showError(_ error: Error) {
        alert = Alert(title: Text("errorOccured"), message: Text(error.localizedDescription))
    }
}
