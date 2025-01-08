//
//  AppNotificationView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppNotificationView: View {
    let notification: AppNotificationData?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: notification?.isLoading == true ? "progress.indicator" : notification?.icon ?? ""
            )

            Text(notification?.title ?? "")
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(.black.opacity(0.2))
        .background(.regularMaterial)
        .clipShape(Capsule())
        .fixedSize()
    }
}

#Preview {
    @Previewable @State var appNotificationVM = AppNotificationVM()

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
        .onAppear {
            appNotificationVM.show(AppNotificationData(
                title: "success",
                icon: "checkmark",
                timeout: 2.0
            ))
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
