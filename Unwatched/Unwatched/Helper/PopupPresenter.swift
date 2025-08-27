//
//  PopupPresenter.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UIKit

@MainActor
class PopupPresenter: ObservableObject {
    private var popupWindow: UIWindow?

    func show<Content: View>(@ViewBuilder content: @escaping (@escaping () -> Void) -> Content) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        popupWindow = UIWindow(windowScene: scene)
        popupWindow?.backgroundColor = .clear
        popupWindow?.frame = scene.coordinateSpace.bounds

        let popup = PopupContainer(content: content, presenter: self)

        popupWindow?.rootViewController = UIHostingController(rootView: popup)
        popupWindow?.rootViewController?.view.backgroundColor = .clear
        popupWindow?.makeKeyAndVisible()
    }

    func dismiss() {
        // This will be called by PopupContainer after animation completes
        popupWindow?.isHidden = true
        popupWindow = nil
    }
}

private struct PopupContainer<Content: View>: View {
    let content: (@escaping () -> Void) -> Content
    let presenter: PopupPresenter

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black.opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            content(dismissWithAnimation)
                .shadow(radius: 20)
                .scaleEffect(isVisible ? 1 : 0.8)
                .opacity(isVisible ? 1 : 0)
                .animation(.bouncy, value: isVisible)
        }
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.spring()) {
            isVisible = false
        }

        // Wait for animation to complete before dismissing the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            presenter.dismiss()
        }
    }
}
#endif
