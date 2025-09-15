//
//  AppNotificationView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppNotificationView: View {
    let notification: AppNotificationData?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                if notification?.isLoading == true || notification?.icon != nil {
                    Image(systemName: notification?.isLoading == true
                            ? "progress.indicator"
                            : notification?.icon ?? ""
                    )
                }

                Text(notification?.title ?? "")
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }

            if let error = notification?.error {
                Text(verbatim: error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .frame(idealWidth: 250, maxWidth: 250)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .apply {
            if #available(iOS 26, macOS 26, *) {
                $0
                    .foregroundStyle(hasError ? .white : .primary)
                    .glassEffect(
                        .regular.tint(hasError ? .red : .clear).interactive(),
                        in: clipShape
                    )
            } else {
                $0
                    .foregroundStyle(.white)
                    .background(
                        hasError
                            ? .red
                            : .black.opacity(0.2)
                    )
                    .background(.regularMaterial)
                    .clipShape(clipShape)
            }
        }
        .fixedSize()
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -20 {
                        withAnimation {
                            onDismiss()
                        }
                    }
                }
        )
    }

    var hasError: Bool {
        notification?.isError == true
    }

    var clipShape: some Shape {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
    }

    var color: Color {
        notification?.error != nil
            ? .red
            : .black.opacity(0.2)
    }

    func reportMessage(_ error: Error) {
        let versionInfo = Device.versionInfo
        let body = """
            \(versionInfo)

            \(error)
            """
        let url = UrlService.getEmailUrl(title: error.localizedDescription, body: body)
        UrlService.open(url)
    }
}

struct PreviewableAppNotificationView: View {
    @Environment(AppNotificationVM.self) var appNotificationVM

    var body: some View {

        VStack {
            Button {
                appNotificationVM.show(AppNotificationData(
                    title: "success",
                    icon: "checkmark",
                    timeout: 2.0
                ))
            } label: {
                Text(verbatim: "Simple")
            }

            Button {
                appNotificationVM.show("Some error", isError: true)
            } label: {
                Text(verbatim: "Error")
            }

            Button {
                appNotificationVM.show(.error(VideoError.emptyYoutubeId))
            } label: {
                Text(verbatim: "Error")
            }

            Button {
                appNotificationVM.show(AppNotificationData(
                    title: "loading",
                    icon: "arrow.clockwise",
                    isLoading: true,
                    timeout: 0
                ))
            } label: {
                Text(verbatim: "Loading")
            }

            Button {
                fullTest()
            } label: {
                Text(verbatim: "full test")
            }
        }
        .onAppear {
            fullTest()
        }
        .frame(maxHeight: .infinity)
    }

    func fullTest() {
        appNotificationVM.show(.addingVideo)
        Task {
            do {
                try await Task.sleep(for: .seconds(0.1))
                appNotificationVM.show(.addedVideo)
            } catch { }
        }
    }
}

#Preview {
    ZStack {}
        .sheet(isPresented: .constant(true)) {
            PreviewableAppNotificationView()
                .appNotificationOverlay(topPadding: 20)
        }
}
