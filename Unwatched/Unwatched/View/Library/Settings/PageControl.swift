//
//  PageControl.swift
//  Unwatched
//

import SwiftUI
import UIKit

struct PageControl: UIViewRepresentable {
    @Binding var currentPage: Int?
    var numberOfPages: Int

    func makeCoordinator() -> Coordinator {
        return Coordinator(currentPage: $currentPage)
    }

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.numberOfPages = 1
        control.pageIndicatorTintColor = UIColor(.white.opacity(0.3))
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

        @objc
        func pageControlDidFire(_ control: UIPageControl) {
            currentPage.wrappedValue = control.currentPage
        }
    }
}
