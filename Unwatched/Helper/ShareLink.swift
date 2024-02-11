//
//  ShareLink.swift
//  Unwatched
//

import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}

struct MyShareLink: Identifiable {
    let id = UUID()
    let url: URL
}
