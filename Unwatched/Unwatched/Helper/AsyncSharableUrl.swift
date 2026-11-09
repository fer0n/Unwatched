//
//  AsyncSharableUrl.swift
//  Unwatched
//

import Foundation
import SwiftUI

#if os(iOS) || os(visionOS)
struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
#endif

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
