//
//  ShareCardView.swift
//  UnwatchedShareExtension
//
//  Minimal confirmation card shown while the shared URL is handed off to the app.
//

import SwiftUI

@Observable
final class ShareCardModel {
    enum State {
        case adding
        case added
        case noLink
        case notYouTube
    }

    var state: State = .adding
}

struct ShareCardView: View {
    @Bindable var model: ShareCardModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                icon
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(minWidth: 200)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.snappy(duration: 0.28), value: model.state)
    }

    @ViewBuilder
    private var icon: some View {
        switch model.state {
        case .adding:
            ProgressView()
                .controlSize(.large)
        case .added:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .transition(.scale.combined(with: .opacity))
        case .noLink, .notYouTube:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var title: String {
        switch model.state {
        case .adding: return "Adding…"
        case .added: return "Added to Unwatched"
        case .noLink: return "No link found"
        case .notYouTube: return "Not a YouTube link"
        }
    }
}
