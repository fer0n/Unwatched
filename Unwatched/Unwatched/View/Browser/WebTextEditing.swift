//
//  WebTextEditing.swift
//  Unwatched
//

#if os(iOS)
import Combine
import WebKit

/// Text fields on web pages post none of UIKit's editing notifications, so the page reports them.
enum WebTextEditing {
    static let isEditing = CurrentValueSubject<Bool, Never>(false)
    private static let handlerName = "textEditing"

    @MainActor
    static func install(in config: WKWebViewConfiguration) {
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(Handler.shared, name: handlerName)
    }

    static func endEditing() {
        isEditing.send(false)
    }

    @MainActor
    private final class Handler: NSObject, WKScriptMessageHandler {
        static let shared = Handler()

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            WebTextEditing.isEditing.send(message.body as? Bool ?? false)
        }
    }

    private static let script = """
    (() => {
        const nonText = ['button', 'checkbox', 'color', 'file', 'hidden', 'image', 'radio', 'range', 'reset', 'submit'];
        const post = editing => window.webkit?.messageHandlers?.\(handlerName)?.postMessage(editing);
        const isEditable = el => el.tagName === 'IFRAME' || el.isContentEditable
            || (el.tagName === 'TEXTAREA' && !el.readOnly)
            || (el.tagName === 'INPUT' && !el.readOnly && !nonText.includes(el.type));
        const report = () => setTimeout(() => {
            let el = document.activeElement;
            while (el?.shadowRoot?.activeElement) el = el.shadowRoot.activeElement;
            post(document.hasFocus() && !!el && isEditable(el));
        }, 0);
        for (const type of ['focusin', 'focusout']) document.addEventListener(type, report, true);
        for (const type of ['focus', 'blur']) window.addEventListener(type, report);
        window.addEventListener('pagehide', () => post(false));
    })();
    """
}
#endif
