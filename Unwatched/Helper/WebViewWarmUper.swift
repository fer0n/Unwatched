import WebKit
import UIKit

@MainActor
public class WebViewWarmUper {
    static func prepare() async {
        let webView = WKWebView()
        webView.loadHTMLString("", baseURL: nil)
    }
}
