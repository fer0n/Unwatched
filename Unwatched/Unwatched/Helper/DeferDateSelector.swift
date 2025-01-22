//
//  DeferDateSelector.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DeferDateButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(color, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .white : color)
    }
}

struct DeferDateSelector: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @State var date: Date
    @State var clearDate = false
    let detectedDate: (Binding<IdentifiableDate?>)?
    let video: Video?
    let onSuccess: (() -> Void)?

    init(video: Video?, detectedDate: (Binding<IdentifiableDate?>)? = nil, onSuccess: (() -> Void)?) {
        self.video = video
        self.detectedDate = detectedDate
        self.onSuccess = onSuccess

        let fallbackDate = video?.deferDate
            ?? Calendar.current.date(byAdding: .second, value: 20, to: Date.now)
            ?? .now

        _date = State(initialValue: detectedDate?.wrappedValue?.date ?? fallbackDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("deferDateHelper")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                        .padding([.horizontal, .bottom], 10)

                    if let detectedDate = detectedDate?.wrappedValue?.date {
                        Button {
                            self.date = detectedDate
                        } label: {
                            Text(formatted(detectedDate))
                        }
                        .buttonStyle(DeferDateButtonStyle(
                            isSelected: date == detectedDate,
                            color: theme.color
                        ))
                    }

                    Button {
                        date = Date.tomorrow
                    } label: {
                        Text("tomorrow")
                    }
                    .buttonStyle(DeferDateButtonStyle(
                        isSelected: date == Date.tomorrow,
                        color: theme.color
                    ))
                }
                .padding(.horizontal)

                DatePicker("selectDate", selection: $date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .myNavigationTitle("deferVideo", showBack: false)
                    .toolbar {
                        DismissToolbarButton()

                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                if let video, let videoId = video.persistentId {
                                    if clearDate {
                                        VideoService.cancelDeferVideo(video)
                                    } else {
                                        VideoService.deferVideo(
                                            videoId,
                                            deferDate: date
                                        )
                                        onSuccess?()
                                    }
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .fontWeight(.bold)
                            .accessibilityLabel("confirm")
                            .disabled(video == nil || (!clearDate && date <= Date()))
                        }
                    }
                    .padding(.horizontal)

                if video?.deferDate != nil, !clearDate {
                    Button(role: .destructive) {
                        clearDate = true
                    } label: {
                        Text("removeDeferDate")
                            .frame(maxWidth: .infinity)
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(DeferDateButtonStyle(isSelected: false, color: .red))
                    .padding()
                }
            }
        }
    }

    func formatted(_ date: Date) -> String {
        DateFormatter.localizedString(
            from: date,
            dateStyle: .medium,
            timeStyle: .short
        )
    }
}

struct DateSelectorSheet: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @State private var isPresented: Bool = false
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var show: Binding<Bool>?
    let video: Video?
    let detectedDate: Binding<IdentifiableDate?>?
    let onSuccess: (() -> Void)?

    init(
        show: (Binding<Bool>)? = nil,
        video: Video?,
        detectedDate: (Binding<IdentifiableDate?>)? = nil,
        onSuccess: (() -> Void)?) {
        self.show = show
        self.video = video
        self.detectedDate = detectedDate
        self.onSuccess = onSuccess
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                DeferDateSelector(
                    video: video,
                    detectedDate: detectedDate,
                    onSuccess: onSuccess
                )
                .presentationDetents([.fraction(0.6)])
                .tint(theme.color)
            }
            .onChange(of: show?.wrappedValue ?? false) {
                if let show {
                    isPresented = show.wrappedValue
                }
            }
            .onChange(of: detectedDate?.wrappedValue?.date) {
                if detectedDate?.wrappedValue?.date != nil {
                    isPresented = true
                }
            }
    }

    func onDismiss() {
        if !SheetPositionReader.shared.landscapeFullscreen {
            navManager.showMenu = true
        }
        detectedDate?.wrappedValue = nil
        show?.wrappedValue = false
    }
}

extension View {
    func dateSelectorSheet(
        show: Binding<Bool>? = nil,
        video: Video?,
        detectedDate: (Binding<IdentifiableDate?>)? = nil,
        onSuccess: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            DateSelectorSheet(
                show: show,
                video: video,
                detectedDate: detectedDate,
                onSuccess: onSuccess
            )
        )
    }
}

#Preview {
    DeferDateSelector(
        video: Video.getDummy(),
        detectedDate: .constant(IdentifiableDate(Date.now)),
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
