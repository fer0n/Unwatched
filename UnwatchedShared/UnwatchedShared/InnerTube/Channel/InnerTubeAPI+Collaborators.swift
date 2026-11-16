//
//  InnerTubeAPI+Collaborators.swift
//  UnwatchedShared
//

import Foundation

extension ITVideo {
    /// Fills `collaborators` from a byline's collaborators dialog; `channelId` becomes the first.
    func withCollaborators(in byline: Any?) -> ITVideo {
        var found: [ITCollaborator] = []
        Self.collectCollaborators(in: byline, into: &found)
        guard found.count > 1 else { return self }
        var video = self
        video.collaborators = found
        video.channelId = found[0].channelId
        return video
    }

    private static func collectCollaborators(in object: Any?, into found: inout [ITCollaborator]) {
        if let dict = object as? [String: Any] {
            if let item = dict["listItemViewModel"] as? [String: Any] {
                if let collaborator = collaborator(from: item),
                   !found.contains(where: { $0.channelId == collaborator.channelId }) {
                    found.append(collaborator)
                }
                return
            }
            for value in dict.values {
                collectCollaborators(in: value, into: &found)
            }
        } else if let array = object as? [Any] {
            for item in array {
                collectCollaborators(in: item, into: &found)
            }
        }
    }

    private static func collaborator(from item: [String: Any]) -> ITCollaborator? {
        guard let title = (item["title"] as? [String: Any])?["content"] as? String,
              let command = ((item["rendererContext"] as? [String: Any])?["commandContext"] as? [String: Any])
                .flatMap({ ($0["onTap"] as? [String: Any])?["innertubeCommand"] as? [String: Any] }),
              let channelId = (command["browseEndpoint"] as? [String: Any])?["browseId"] as? String,
              channelId.hasPrefix("UC")
        else { return nil }
        return ITCollaborator(channelId: channelId, title: title)
    }
}
