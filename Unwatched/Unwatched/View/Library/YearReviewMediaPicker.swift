//
//  YearReviewMediaPicker.swift
//  Unwatched
//

import SwiftUI

struct YearReviewMediaPicker: View {
    @Binding var media: YearReviewMedia
    let color: Color

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            mediaChip("yearReviewAll", .all)
            mediaChip("yearReviewVideosLabel", .videos)
            mediaChip("yearReviewAudioPodcasts", .podcasts)
        }
        .padding(4)
        .background(.white.opacity(0.12), in: .capsule)
        .sensoryFeedback(.selection, trigger: media)
        .padding(.bottom, 12)
    }

    private func mediaChip(_ label: LocalizedStringKey, _ value: YearReviewMedia) -> some View {
        let isSelected = media == value
        return Button {
            withAnimation(.snappy(duration: 0.22)) { media = value }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? color.mix(with: .black, by: 0.4) : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule().fill(.white).matchedGeometryEffect(id: "chip", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
