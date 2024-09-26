//
//  AspectRatioPicker.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AspectRatioPicker: View {
    @Bindable var subscription: Subscription

    var body: some View {
        let options: [Double?] = [nil] + Const.videoAspectRatios
        CapsulePicker(selection: $subscription.customAspectRatio,
                      options: options,
                      label: {
                        var text = ""
                        var img = "rectangle.ratio.16.to.9"
                        if let aspectRatio = $0 {
                            text = getAspectRatioName(aspectRatio)
                            img = getAspectRatioSystemImage(aspectRatio)
                        } else {
                            let defaultAspectRatio = getAspectRatioName(Const.defaultVideoAspectRatio)
                            text = String(localized: "defaultAspectRatio (\(defaultAspectRatio))")
                            img = "aspectratio"
                        }
                        return (text, img)
                      },
                      menuLabel: "videoAspectRatio")
    }

    func getAspectRatioName(_ value: Double) -> String {
        switch value {
        case 18/9:
            return "18/9"
        case 16/9:
            return "16/9"
        case 1/1:
            return "1/1"
        case 4/3:
            return "4/3"
        default:
            return "-"
        }
    }

    func getAspectRatioSystemImage(_ value: Double) -> String {
        if value >= 16/9 {
            return "rectangle.ratio.16.to.9"
        } else if value >= 4/3 {
            return "rectangle.ratio.4.to.3"
        } else if value <= 1 {
            return "square"
        }
        return "rectangle.ratio.16.to.9"
    }
}
