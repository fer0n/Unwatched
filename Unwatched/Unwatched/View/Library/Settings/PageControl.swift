//
//  PageControl.swift
//  Unwatched
//

import SwiftUI
import UIKit

struct PageControl: UIViewRepresentable {
    @Binding var currentPage: Int?
    let numberOfPages: Int
    var normalColor: UIColor = .white.withAlphaComponent(0.4)

    func makeCoordinator() -> Coordinator {
        return Coordinator(currentPage: $currentPage)
    }

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.numberOfPages = 1
        control.pageIndicatorTintColor = normalColor
        control.currentPageIndicatorTintColor = UIColor(.white)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.pageControlDidFire(_:)),
            for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.currentPage = $currentPage
        control.numberOfPages = numberOfPages
        if let currentPage {
            control.currentPage = currentPage
        }
    }

    class Coordinator {
        var currentPage: Binding<Int?>

        init(currentPage: Binding<Int?>) {
            self.currentPage = currentPage
        }

        @MainActor @objc
        func pageControlDidFire(_ control: UIPageControl) {
            currentPage.wrappedValue = control.currentPage
        }
    }
}
