import SwiftUI
import UnwatchedShared

struct CapsuleSegmentedControl<SelectionType: Hashable>: View {
    @Binding var selection: SelectionType
    let items: [CapsuleSegmentItem<SelectionType>]

    init(selection: Binding<SelectionType>, items: [CapsuleSegmentItem<SelectionType>]) {
        self._selection = selection
        self.items = items
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                Button {
                    selection = item.value
                } label: {
                    Text(item.title)
                        .fontWeight(.regular)
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(selection == item.value ? .automaticWhite : .primary)
                .background(
                    ZStack {
                        if selection == item.value {
                            Capsule()
                                .fill(Color.foregroundGray)
                                .matchedGeometryEffect(id: "capsule", in: namespace)
                        }
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
        .background(
            Capsule()
                .fill(Color.insetBackgroundColor)
        )
        .sensoryFeedback(Const.sensoryFeedback, trigger: selection)
    }

    @Namespace private var namespace
}

struct CapsuleSegmentItem<Value: Hashable> {
    let title: LocalizedStringKey
    let value: Value
}

#Preview {
    @Previewable @State var selection: Int = 0

    VStack {
        CapsuleSegmentedControl(
            selection: $selection,
            items: [
                CapsuleSegmentItem(title: "First", value: 0),
                CapsuleSegmentItem(title: "Second", value: 1)
            ]
        )
        .frame(width: 300)

        Text(verbatim: "Selected: \(selection)")
            .padding()
    }
    .padding()
}
