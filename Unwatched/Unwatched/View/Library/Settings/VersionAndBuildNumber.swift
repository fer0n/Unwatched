//
//  VersionAndBuildNumber.swift
//  Unwatched
//

import SwiftUI

struct VersionAndBuildNumber: View {
    var body: some View {

        Link(
            VersionAndBuildNumber.both,
            destination: UrlService.releasesUrl
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
    }

    static var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static var buildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return " (\(build))"
        }
        return ""
    }

    static var both: String {
        "v\(VersionAndBuildNumber.version ?? "-")\(VersionAndBuildNumber.buildNumber)"
    }
}

#Preview {
    VersionAndBuildNumber()
}
