import Foundation
import Testing

@testable import PortBar

struct RepoScannerTests {
    @Test func parsesBranchWithRemoteTracking() {
        #expect(
            RepoScanner.parseBranch(from: "## feature/repo-watch...origin/feature/repo-watch")
                == "feature/repo-watch")
    }

    @Test func parsesDetachedBranch() {
        #expect(RepoScanner.parseBranch(from: "## HEAD (no branch)") == "detached")
    }

    @Test func parsesChangeCounts() {
        let counts = RepoScanner.parseChangeCounts([
            " M Sources/PortBar/MenuContentView.swift",
            "A  Sources/PortBar/RepoScanner.swift",
            "?? Tests/PortBarTests/RepoScannerTests.swift",
        ])

        #expect(counts.changed == 2)
        #expect(counts.untracked == 1)
    }

    @Test func parsesRemoteHosts() {
        #expect(RepoScanner.parseRemoteHost("https://github.com/AmirAjaj/PortBar.git") == "github.com")
        #expect(RepoScanner.parseRemoteHost("git@github.com:AmirAjaj/PortBar.git") == "github.com")
        #expect(RepoScanner.parseRemoteHost(nil) == nil)
    }

    @Test func codexReviewURLUsesWebDeeplinkWithRepositoryPrompt() throws {
        let repository = GitRepositoryStatus(
            path: "/Users/amirajaj/Desktop/PortBar",
            name: "PortBar",
            branch: "main",
            changedCount: 2,
            untrackedCount: 1,
            ahead: 0,
            behind: 0,
            remoteHost: "github.com")

        let url = try #require(CodexActions.reviewChatURL(for: repository))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.scheme == "https")
        #expect(components.host == "chatgpt.com")
        #expect(components.path == "/codex/deeplink")
        #expect(queryItems.first { $0.name == "prompt" }?.value?.contains(repository.path) == true)
        #expect(queryItems.first { $0.name == "prompt" }?.value?.contains(repository.branch) == true)
        #expect(queryItems.first { $0.name == "prompt" }?.value?.contains("do not edit files") == true)
    }
}
