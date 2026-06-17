//
//  YoutubeApiKeyView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YoutubeApiKeyView: View {
    @CloudStorage(Const.customYoutubeApiKey) var customYoutubeApiKey: String = ""

    @State private var apiKeyStatus: ApiKeyStatus = .idle

    var body: some View {
        MySection("youtubeApiKey", footer: "customYoutubeApiKeyHelper") {
            HStack {
                TextField("customYoutubeApiKey", text: $customYoutubeApiKey)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    #endif
                    .onSubmit(verifyApiKey)
                    .onChange(of: customYoutubeApiKey) {
                        apiKeyStatus = .idle
                    }

                statusIndicator
            }

            if case .invalid(let message) = apiKeyStatus {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Link(destination: UrlService.youtubeApiKeyUrl) {
                Text("createYoutubeApiKey")
            }
            .linkHoverEffect()
        }
    }

    enum ApiKeyStatus: Equatable {
        case idle
        case checking
        case valid
        case invalid(String)
    }

    @ViewBuilder
    var statusIndicator: some View {
        switch apiKeyStatus {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func verifyApiKey() {
        let key = customYoutubeApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            apiKeyStatus = .idle
            return
        }
        apiKeyStatus = .checking
        Task { @MainActor in
            do {
                try await YoutubeDataAPI.verifyApiKey(key)
                apiKeyStatus = .valid
            } catch {
                apiKeyStatus = .invalid(error.localizedDescription)
            }
        }
    }
}

#Preview {
    MyForm {
        YoutubeApiKeyView()
    }
}
