//
//  DeferDateSelector.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DeferDateSelector: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @State var date: Date?

    let detectedDate: (Binding<Date?>)?
    let video: Video?
    let onSuccess: (() -> Void)?

    init(video: Video?, detectedDate: (Binding<Date?>)? = nil, onSuccess: (() -> Void)?) {
        self.video = video
        self.detectedDate = detectedDate
        self.onSuccess = onSuccess

        let initialDate = detectedDate?.wrappedValue ?? video?.deferDate ?? nextFullHour
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        VStack {
            Text("deferVideo")
                .font(.headline)
                .fontWeight(.black)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()

            Text("deferDateHelper")
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .font(.footnote)
                .padding(.bottom)

            if let detectedDateValue {
                Button {
                    self.date = detectedDateValue
                } label: {
                    Text(formatted(detectedDateValue))
                }
                .buttonStyle(DeferDateButtonStyle(
                    isHighlighted: date == detectedDateValue,
                    color: theme.color,
                    contrastColor: theme.contrastColor
                ))
            }

            Button {
                date = nextFullHour
            } label: {
                Text("selected")
            }
            .buttonStyle(DeferDateButtonStyle(
                isHighlighted: date != nil && date != detectedDateValue,
                color: theme.color,
                contrastColor: theme.contrastColor
            ))

            Button(role: .destructive) {
                date = nil
            } label: {
                Text("none")
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .buttonStyle(DeferDateButtonStyle(
                isHighlighted: date == nil,
                color: .red,
                contrastColor: .white
            ))
        }
        .padding(.horizontal)

        DatePicker("selectDate", selection: Binding<Date>(get: {self.date ?? Date()}, set: {self.date = $0}))
            #if os(iOS)
            .datePickerStyle(.wheel)
            #else
            .padding(.vertical)
            .datePickerStyle(.graphical)
            #endif
            .labelsHidden()
            .myNavigationTitle("deferVideo", showBack: false)
            .padding(.horizontal)
            .disabled(date == nil)

        HStack {
            DismissSheetButton()
                .buttonStyle(DeferDateButtonStyle(
                    isHighlighted: false,
                    color: theme.color,
                    contrastColor: theme.contrastColor
                ))

            Button("confirm", systemImage: "checkmark") {
                if let video, let videoId = video.persistentId {
                    if let date {
                        VideoService.deferVideo(
                            videoId,
                            deferDate: date
                        )
                        onSuccess?()
                    } else {
                        VideoService.cancelDeferVideo(video)
                    }
                    dismiss()
                }
            }
            .buttonStyle(DeferDateButtonStyle(
                isHighlighted: true,
                color: theme.color,
                contrastColor: theme.contrastColor
            ))
            .disabled(!isDirty)
        }
        .fontWeight(.medium)
        .padding()
    }

    var detectedDateValue: Date? {
        detectedDate?.wrappedValue
    }

    var isDirty: Bool {
        video?.deferDate != date
    }

    var nextFullHour: Date {
        Calendar.current.nextDate(
            after: Date.now,
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        )
        ?? .now
    }

    func formatted(_ date: Date) -> String {
        DateFormatter.localizedString(
            from: date,
            dateStyle: .medium,
            timeStyle: .short
        )
    }
}

#Preview {
    DeferDateSelector(
        video: Video.getDummy(),
        detectedDate: .constant(Date.now),
        onSuccess: nil
    )
    // .modelContainer(DataProvider.previewContainer)

    //    @Previewable @State var show = true
    //
    //    Button {
    //        show = true
    //    } label: {
    //        Text(verbatim: "Show")
    //    }
    //    .dateSelectorSheet(show: $show, video: Video.getDummy())
    //    .modelContainer(DataProvider.previewContainerFilled)
}
