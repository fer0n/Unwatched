//
//  FullscreenControlBand.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ControlBand: Equatable {
    let edge: VerticalEdge
    let height: CGFloat
    let leadingOcclusion: CGFloat
    let trailingOcclusion: CGFloat
}

struct FullscreenControlBand: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @Environment(PlayerManager.self) var player

    let band: ControlBand
    @Binding var autoHideVM: AutoHideVM
    var sleepTimerVM: SleepTimerViewModel

    let edgePadding: CGFloat = 30

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    autoHideVM.setShowControls()
                }

            controls
                .modifier(ShowFullscreenControlsViewModifier(showControls: showControls))
        }
        .frame(height: band.height)
        .offset(y: band.height)
    }

    var controls: some View {
        HStack(spacing: FullscreenPlayerControls.rowSpacing) {
            PlayerScrubber(
                height: 15,
                inlineTime: true,
                translucent: true,
                showBackground: false,
                fillColor: .primary,
                trackColor: .secondary,
                timeColor: .primary,
                verticalHitSlop: 14,
                showThumbnailPreview: true
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .backgroundTransparentEffect(fallback: .ultraThinMaterial, shape: Capsule())

            FullscreenPlayerControls(
                autoHideVM: $autoHideVM,
                arrowEdge: band.edge == .top ? .top : .bottom,
                sleepTimerVM: sleepTimerVM,
                showLeft: false,
                secondary: true,
                axis: .horizontal
            )
        }
        .padding(.leading, inset(band.leadingOcclusion))
        .padding(.trailing, inset(band.trailingOcclusion))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(TapGesture().onEnded {
            if fullscreenControlsSetting == .autoHide {
                autoHideVM.setShowControls()
            }
        })
    }

    func inset(_ occlusion: CGFloat) -> CGFloat {
        occlusion > 0 ? occlusion + FullscreenPlayerControls.rowSpacing : edgePadding
    }

    var showControls: Bool {
        fullscreenControlsSetting == .enabled
            || !player.isPlaying
            || autoHideVM.showControls
    }
}

extension GeometryProxy {
    /// A deep top or bottom safe area in landscape: a closed iPhone Duo's camera edge
    var landscapeControlBand: ControlBand? {
        let height = max(safeAreaInsets.top, safeAreaInsets.bottom)
        guard height > 40 else { return nil }
        let edge: VerticalEdge = safeAreaInsets.bottom > safeAreaInsets.top ? .bottom : .top
        var leading: CGFloat = 0
        var trailing: CGFloat = 0
        #if os(iOS)
        if #available(iOS 27.1, *) {
            for region in reservedRegions(kind: .occlusion) {
                if region.frame.midX < size.width / 2 {
                    leading = max(leading, region.frame.maxX)
                } else {
                    trailing = max(trailing, size.width - region.frame.minX)
                }
            }
        }
        #endif
        return ControlBand(edge: edge, height: height, leadingOcclusion: leading, trailingOcclusion: trailing)
    }

    func fold(isLandscape: Bool) -> CGRect? {
        #if os(iOS)
        guard #available(iOS 27.1, *) else { return nil }
        return reservedRegions(kind: .division)
            .map(\.frame)
            .first { isLandscape ? $0.height > $0.width : $0.width > $0.height }
        #else
        return nil
        #endif
    }
}
