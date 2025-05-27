//
//  VersionAndBuildNumber.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VersionAndBuildNumber: View {
    var body: some View {
        Link(
            Device.buildNumberAndVersion,
            destination: UrlService.releasesUrl
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VersionAndBuildNumber()
}
