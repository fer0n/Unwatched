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
                Button {
                    reportMessage(error)
                } label: {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                    Text("reportAnIssue")
                }
                .buttonStyle(.bordered)
                .tint(.black)
                .buttonBorderShape(.capsule)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            notification?.error != nil
                ? .red
                : .black.opacity(0.2)
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
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

    func reportMessage(_ error: Error) {
        let versionInfo = HelpView.versionInfo
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

    let errorMessage = AppNotificationData(
        title: "errorOccured",
        error: VideoError.emptyYoutubeId,
        icon: Const.errorSF,
        timeout: 0
    )

    return VStack {
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
            appNotificationVM.show(errorMessage)
        } label: {
            Text(verbatim: "Error")
        }
        .onAppear {
            appNotificationVM.show(errorMessage)
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
            let notification = AppNotificationData(
                title: "addingVideo",
                icon: Const.queueTopSF,
                isLoading: true,
                timeout: 0
            )
            appNotificationVM.show(notification)
            Task {
                do {
                    try await Task.sleep(for: .seconds(0.1))
                    let notification = AppNotificationData(
                        title: "addedVideo",
                        icon: Const.checkmarkSF,
                        timeout: 2
                    )
                    appNotificationVM.show(notification)
                } catch { }
            }
        } label: {
            Text(verbatim: "full test")
        }
    }
    .frame(maxHeight: .infinity)
    .appNotificationOverlay($appNotificationVM)
}
