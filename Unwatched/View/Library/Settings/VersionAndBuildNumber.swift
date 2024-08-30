//
//  VersionAndBuildNumber.swift
//  Unwatched
//

import SwiftUI

struct VersionAndBuildNumber: View {
    var body: some View {

        if let version = version {
            Text(verbatim: "v\(version)\(buildNumber)")
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.system(size: 15, weight: .medium))
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
