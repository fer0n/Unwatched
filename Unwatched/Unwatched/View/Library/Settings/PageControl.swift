import SwiftUI

#if os(iOS)
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
#else
struct PageControl: View {
    @Binding var currentPage: Int?
    let numberOfPages: Int
    var normalColor: Color = .white.opacity(0.4)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.white : normalColor)
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        currentPage = index
                    }
            }
        }
    }
}
#endif

// Common interface for both platforms
struct AnyPageControl: View {
    @Binding var currentPage: Int?
    let numberOfPages: Int

    var body: some View {
        PageControl(currentPage: $currentPage, numberOfPages: numberOfPages)
    }
}
