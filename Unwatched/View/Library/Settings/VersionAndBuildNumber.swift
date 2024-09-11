//
//  VersionAndBuildNumber.swift
//  Unwatched
//

import SwiftUI

struct VersionAndBuildNumber: View {
    var body: some View {

        if let version = version {
            Link("v\(version)\(buildNumber)", destination: UrlService.releasesUrl)
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }

    var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return " (\(build))"
        }
        return ""
    }
}

#Preview {
    VersionAndBuildNumber()
}
