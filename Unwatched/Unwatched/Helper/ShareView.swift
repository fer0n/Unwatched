//
//  ShareView.swift
//  Unwatched
//

import SwiftUI

struct ShareView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIActivityViewController

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
