//
//  YearReviewView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Const.themeColor) private var theme = ThemeColor()

    @State private var viewModel = YearReviewVM()
    @State private var index = 0
    @State private var isReplaying = false
    @State private var slideStart = Date.now
    @State private var slideDone = false
    @State private var skipped = false
    @State private var skipCount = 0
    @State private var media = YearReviewMedia.all
    @FocusState private var isFocused: Bool

    var body: some View {
        let cards = viewModel.review?.cards ?? [.intro]
        let card = cards[min(index, cards.count - 1)]
        let duration = viewModel.review.map { card.duration(for: $0) } ?? 0

        ZStack {
            Color.clear.overlay {
                ForEach(cards, id: \.self) { item in
                    let isActive = item == card && !isReplaying
                    YearReviewCardView(
                        card: item,
                        review: viewModel.review,
                        isLoading: viewModel.isLoading,
                        images: viewModel.images,
                        media: media,
                        isActive: isActive,
                        skipped: isActive && skipped,
                        skipCount: skipCount
                    )
                    .opacity(isActive ? 1 : 0)
                    .scaleEffect(isActive ? 1 : 0.92)
                    .accessibilityHidden(item != card)
                }
            }
            .padding(30)
            .frame(maxWidth: 500, maxHeight: .infinity)
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                tapZone(label: "previous") { step(-1, count: cards.count) }
                    .containerRelativeFrame(.horizontal) { width, _ in width / 3 }
                tapZone(label: "next") { skipOrAdvance(count: cards.count) }
            }
            .simultaneousGesture(swipe(count: cards.count))
        }
        .background {
            ZStack {
                background(position: Double(min(index, cards.count - 1)), card: card)
                YearReviewConfetti(isActive: card == .outro && !isReplaying, color: theme.color)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            topBar(cards: cards, duration: duration)
        }
        .overlay(alignment: .bottom) {
            if card == .topChannels, viewModel.review?.hasBothMedia == true {
                YearReviewMediaPicker(media: $media, color: theme.color)
            }
        }
        .sensoryFeedback(.selection, trigger: index)
        .sensoryFeedback(.impact(weight: .medium), trigger: skipped) { $1 }
        .foregroundStyle(.white)
        .tint(.white)
        .environment(\.colorScheme, .dark)
        #if os(iOS)
        .statusBarHidden()
        #endif
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.year) {
            index = 0
            media = .all
        }
        .onChange(of: index) { restartSlide() }
        .onChange(of: media) { restartSlide() }
        .onChange(of: viewModel.isLoading) { restartSlide() }
        .task(id: slideStart) {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            slideDone = true
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            step(-1, count: cards.count)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            skipOrAdvance(count: cards.count)
            return .handled
        }
        .onAppear { isFocused = true }
    }

    private func skipOrAdvance(count: Int) {
        guard slideDone || viewModel.isLoading else {
            skipped = true
            skipCount += 1
            slideDone = true
            return
        }
        step(1, count: count)
    }

    private func restartSlide() {
        slideStart = .now
        slideDone = false
        skipped = false
    }

    private func step(_ offset: Int, count: Int) {
        guard !viewModel.isLoading else { return }
        let next = index + offset
        guard next >= 0, next < count else {
            if next >= count { dismiss() }
            return
        }
        withAnimation(.snappy(duration: 0.22)) {
            index = next
        }
    }

    /// Fades the slide out until its values have reset, then back in so its animations start over.
    private func replay() {
        guard !isReplaying else { return }
        withAnimation(.snappy(duration: 0.22)) { isReplaying = true }
        Task {
            try? await Task.sleep(for: .seconds(YearReviewReset.fadeDuration + 0.1))
            withAnimation(.snappy(duration: 0.22)) { isReplaying = false }
            restartSlide()
        }
    }

    private func tapZone(label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture(perform: action)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    private func topBar(cards: [YearReviewCard], duration: Double) -> some View {
        VStack(spacing: 12) {
            TimelineView(.animation(paused: slideDone || isReplaying)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(slideStart)
                let progress = slideDone || duration <= 0 ? 1 : min(1, elapsed / duration)
                HStack(spacing: 4) {
                    ForEach(cards.indices, id: \.self) { cardIndex in
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(.white.opacity(0.9))
                                        .frame(width: geometry.size.width * fill(cardIndex, progress: progress))
                                }
                            }
                    }
                }
            }
            HStack {
                if viewModel.availableYears.count > 1 {
                    Picker("yearReview", selection: $viewModel.year) {
                        ForEach(viewModel.availableYears, id: \.self) { year in
                            Text(verbatim: String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Spacer()
                barButton(systemName: Const.clearNoFillSF, label: "close") { dismiss() }
            }
            .overlay {
                barButton(systemName: "arrow.counterclockwise", label: "yearReviewReplay", action: replay)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// Down closes the recap, left and right change slides.
    private func swipe(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let width = value.predictedEndTranslation.width
                let height = value.predictedEndTranslation.height
                if abs(width) > abs(height) {
                    guard abs(width) > 80 else { return }
                    step(width < 0 ? 1 : -1, count: count)
                } else if height > 120 {
                    dismiss()
                }
            }
    }

    private func fill(_ cardIndex: Int, progress: Double) -> Double {
        if cardIndex < index { return 1 }
        return cardIndex == index ? progress : 0
    }

    private func barButton(
        systemName: String,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .padding(8)
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
        .buttonStyle(.plain)
    }

    private func background(position: Double, card: YearReviewCard) -> some View {
        let base = theme.color
        let darkness = 0.35 + 0.08 * position.truncatingRemainder(dividingBy: 4)
        return LinearGradient(
            colors: [
                base.mix(with: .black, by: darkness - 0.25),
                base.mix(with: .black, by: darkness + 0.3)
            ],
            startPoint: position.truncatingRemainder(dividingBy: 2) == 0 ? .topLeading : .topTrailing,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.3), value: card)
    }

}

#Preview {
    YearReviewView()
        .previewEnvironments()
}
