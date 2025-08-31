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
                    .foregroundStyle(.primary)
                    .glassEffect(
                        .regular.tint(notification?.error != nil ? .red : .clear).interactive(),
                        in: clipShape
                    )
            } else {
                $0
                    .foregroundStyle(.white)
                    .background(
                        notification?.error != nil
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

#Preview {
    @Previewable @State var appNotificationVM = AppNotificationVM()

    return ZStack {}
        .sheet(isPresented: .constant(true)) {
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
                    appNotificationVM.show(.error(VideoError.emptyYoutubeId))
                } label: {
                    Text(verbatim: "Error")
                }
                .onAppear {
                    appNotificationVM.show(.loading) // error(VideoError.emptyYoutubeId))
                }

                Button {
                    appNotificationVM.show(AppNotificationData(
                        title: "Processing",
                        icon: "arrow.clockwise",
                        isLoading: true,
                        timeout: 0
                    ))
                } label: {
                    Text(verbatim: "Loading")
                }

                Button {
                    appNotificationVM.show(.addingVideo)
                    Task {
                        do {
                            try await Task.sleep(for: .seconds(0.1))
                            appNotificationVM.show(.addedVideo)
                        } catch { }
                    }
                } label: {
                    Text(verbatim: "full test")
                }
            }
            .frame(maxHeight: .infinity)
            .appNotificationOverlay($appNotificationVM)
        }
}
