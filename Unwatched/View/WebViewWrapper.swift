//
//  WebViewWrapper.swift
//  Unwatched
//
import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let videoID: String
    @Binding var playbackSpeed: Double

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor(Color.backgroundColor)
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only load the URL when the web view is first created
        if context.coordinator.didLoadURL == false {
            guard let youtubeURL = URL(string: "https://www.youtube.com/embed/\(videoID)?enablejsapi=1") else { return }
            let request = URLRequest(url: youtubeURL)
            uiView.load(request)
            context.coordinator.didLoadURL = true
        }

        // Change the playback speed
        let script = "document.querySelector('video').playbackRate = \(playbackSpeed);"
        uiView.evaluateJavaScript(script, completionHandler: nil)

        // Inject PiP enabling script
        let enablePiPScript = """
                    let video = document.querySelector('video');
                    video.onplay = function() {
                        if (video.webkitSetPresentationMode) {
                            video.webkitSetPresentationMode("picture-in-picture");
                        }
                    };
                """
        uiView.evaluateJavaScript(enablePiPScript, completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        var didLoadURL = false

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
    }
}
