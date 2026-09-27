//
//  FullscreenPlayerControls.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenPlayerControls: View {
    @AppStorage(Const.preferPlayerType) var preferPlayerType: Bool = false
    @Environment(PlayerManager.self) var player
    @Binding var autoHideVM: AutoHideVM

    var arrowEdge: Edge
    @State var sleepTimerVM: SleepTimerViewModel
    let showLeft: Bool
    /// Use the secondary color for the buttons (landscape) instead of primary (portrait overlay).
    var secondary: Bool = false
    var axis: Axis = .vertical

    var body: some View {
        let size: CGFloat = axis == .vertical ? 32 : 30
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: Self.rowSpacing))

        layout {
            gap

            PlayerMoreMenuButton(
                sleepTimerVM: sleepTimerVM,
                showClear: true,
                showWatched: true,
                isCircleVariant: true
            ) { image in
                image
                    .resizable()
                    .frame(width: size, height: size)
                    .modifier(PlayerControlButtonStyle(isOn: sleepTimerVM.isOn))
            }
            .modifier(RowSlot(axis: axis, size: size))

            gap
            gap

            NextChapterButton(isCircleVariant: true) { image in
                VStack(spacing: 0) {
                    image
                        .resizable()
                        .frame(width: size, height: size)
                        .modifier(PlayerControlButtonStyle())
                    if axis == .vertical {
                        ChapterTimeRemaining()
                            .font(.system(size: 12).monospacedDigit())
                            .lineLimit(1)
                            .opacity(0.8)
                            .fontWidth(.condensed)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.foregroundGray.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
            // always shown; disabled (greyed out) when there is no next chapter
            .disabled(player.nextChapter == nil)
            .modifier(RowSlot(axis: axis, size: size))

            gap
            gap

            FullscreenChapterDescriptionButton(
                arrowEdge: arrowEdge,
                menuOpen: $autoHideVM.keepVisible,
                size: size,
                showPadding: axis == .vertical,
                openTrigger: autoHideVM.descriptionPopoverRequest
            )
            .buttonStyle(.plain)
            .frame(minHeight: size)
            .modifier(RowSlot(axis: axis, size: size))

            gap
            gap

            FullscreenSpeedControl(
                autoHideVM: $autoHideVM,
                arrowEdge: arrowEdge,
                size: size
            )
            .buttonStyle(.plain)
            .modifier(RowSlot(axis: axis, size: size))

            gap
            gap

            CoreNextButton(extendedContextMenu: true,
                           isCircleVariant: true) { image, isOn in
                image
                    .resizable()
                    .frame(width: size, height: size)
                    .modifier(PlayerControlButtonStyle(isOn: isOn))
            }
            .modifier(RowSlot(axis: axis, size: size))

            gap
            gap

            #if os(iOS)
            Group {
                if preferPlayerType {
                    playerTypeButton(size: size)
                        .transition(.blurReplace)
                } else {
                    FullscreenChangeOrientationButton(size: size, showLeft: showLeft)
                        .transition(.blurReplace)
                }
            }
            .buttonStyle(.plain)
            .animation(.default, value: preferPlayerType)
            .modifier(RowSlot(axis: axis, size: size))
            #endif

            gap
        }
        .foregroundStyle(Color.neutralAccentColor)
        .fontWeight(.bold)
        .environment(\.colorScheme, .dark)
        .environment(\.playerControlsSecondary, secondary)
        .padding(axis == .vertical ? .vertical : [])
        .frame(minWidth: 35)
        .fixedSize(horizontal: axis == .horizontal, vertical: false)
        .preferredColorScheme(.dark)
    }

    static let rowSpacing: CGFloat = 14

    private struct RowSlot: ViewModifier {
        let axis: Axis
        let size: CGFloat

        func body(content: Content) -> some View {
            if axis == .horizontal {
                content.frame(width: size, height: size)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    var gap: some View {
        if axis == .vertical {
            Spacer()
        }
    }

    #if os(iOS)
    /// Takes the exit fullscreen button's place; its actions move into this one's menu
    func playerTypeButton(size: CGFloat) -> some View {
        PlayerTypeButton(
            extraGroups: [
                MenuActionGroup(
                    FullscreenExitAction.menuActions(player: player, showLeft: showLeft, includeExit: true)
                )
            ]
        ) { image in
            image
                // not square and no circle variant: sized by font to match the neighbours' ink
                .font(.system(size: 15))
                .symbolRenderingMode(.monochrome)
                .frame(width: size, height: size)
                .modifier(PlayerControlButtonStyle())
        }
    }
    #endif
}

#Preview {
    HStack {
        Rectangle()
            .fill(.gray)
        FullscreenPlayerControls(
            autoHideVM: .constant(AutoHideVM()),
            arrowEdge: .trailing,
            sleepTimerVM: SleepTimerViewModel(),
            showLeft: true)
            .padding()
    }
    .ignoresSafeArea(.all)
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager())
    .environment(NavigationManager())
}
