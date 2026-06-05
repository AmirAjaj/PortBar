import AppKit
import Foundation

/// Opens focused Codex chats for repository workflows.
enum CodexActions {
    private static func reviewPrompt(for repository: GitRepositoryStatus) -> String {
        """
        IMPORTANT: Work in the local repository at "\(repository.path)" on the existing branch "\(repository.branch)".
        Do not create a new branch, do not commit, and do not edit files.

        Please review the current uncommitted changes in this repository and explain very briefly what they change, what they mean, and what they seem to fix. Keep it easy to understand, clear, and short.
        """
    }

    static func reviewChatURL(for repository: GitRepositoryStatus) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "chatgpt.com"
        components.path = "/codex/deeplink"
        components.queryItems = [
            URLQueryItem(name: "prompt", value: reviewPrompt(for: repository))
        ]

        return components.url
    }

    static func reviewCurrentChanges(in repository: GitRepositoryStatus) {
        guard let url = reviewChatURL(for: repository) else { return }
        NSWorkspace.shared.open(url)
    }
}
