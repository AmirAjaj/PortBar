import Foundation

/// Snapshot of one local Git repository.
struct GitRepositoryStatus: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let branch: String
    let changedCount: Int
    let untrackedCount: Int
    let ahead: Int
    let behind: Int
    let remoteHost: String?

    var id: String { path }

    var isDirty: Bool {
        changedCount > 0 || untrackedCount > 0
    }

    var hasRemoteDrift: Bool {
        ahead > 0 || behind > 0
    }

    var needsAttention: Bool {
        isDirty || hasRemoteDrift
    }

    var statusSummary: String {
        var parts: [String] = []
        if changedCount > 0 { parts.append("\(changedCount) changed") }
        if untrackedCount > 0 { parts.append("\(untrackedCount) untracked") }
        if ahead > 0 { parts.append("\(ahead) ahead") }
        if behind > 0 { parts.append("\(behind) behind") }
        return parts.isEmpty ? "clean" : parts.joined(separator: ", ")
    }
}
