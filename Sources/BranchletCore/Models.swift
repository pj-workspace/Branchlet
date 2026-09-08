import Foundation

public struct Repository: Identifiable, Codable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public init(path: String) { self.path = path }
}

public enum ChangeLayer: String, CaseIterable, Codable, Sendable {
    case conflicted, unstaged, staged, untracked
    public var title: String {
        switch self {
        case .conflicted: "冲突"
        case .unstaged: "未暂存"
        case .staged: "已暂存"
        case .untracked: "未跟踪"
        }
    }
}

public struct FileChange: Identifiable, Hashable, Sendable {
    public var id: String { "\(layer.rawValue):\(path)" }
    public let path: String
    public let originalPath: String?
    public let status: String
    public let layer: ChangeLayer
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public var directory: String { (path as NSString).deletingLastPathComponent }
    public init(path: String, originalPath: String? = nil, status: String, layer: ChangeLayer) {
        self.path = path; self.originalPath = originalPath; self.status = status; self.layer = layer
    }
}

public struct GitStatus: Sendable {
    public var branch = "HEAD"
    public var head = ""
    public var upstream: String?
    public var files: [FileChange] = []
    public var isUnborn: Bool { head == "(initial)" }
    public var changedFileCount: Int { Set(files.map(\.path)).count }
    public var hasConflicts: Bool { files.contains { $0.layer == .conflicted } }
    public init() {}
}

public struct Commit: Identifiable, Hashable, Sendable {
    public var id: String { sha }
    public let sha: String
    public let parents: [String]
    public let author: String
    public let date: Date
    public let subject: String
    public let decorations: [String]
    public var shortSHA: String { String(sha.prefix(7)) }
    public var isMerge: Bool { parents.count > 1 }
    public init(sha: String, parents: [String], author: String, date: Date, subject: String, decorations: [String] = []) {
        self.sha = sha; self.parents = parents; self.author = author
        self.date = date; self.subject = subject; self.decorations = decorations
    }
}

public struct Worktree: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let branch: String
    public let isBare: Bool
    public let isPrunable: Bool
    public init(path: String, branch: String, isBare: Bool = false, isPrunable: Bool = false) {
        self.path = path; self.branch = branch; self.isBare = isBare; self.isPrunable = isPrunable
    }
}

public struct RemoteComparison: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let branch: String?
    public let ahead: Int?
    public let behind: Int?
    public let note: String?
    public init(name: String, branch: String?, ahead: Int?, behind: Int?, note: String? = nil) {
        self.name = name; self.branch = branch; self.ahead = ahead; self.behind = behind; self.note = note
    }
}

public struct RepositorySnapshot: Sendable {
    public let path: String
    public let status: GitStatus
    public let commits: [Commit]
    public let worktrees: [Worktree]
    public let remotes: [RemoteComparison]
    public let refreshedAt: Date
    public init(path: String, status: GitStatus, commits: [Commit], worktrees: [Worktree], remotes: [RemoteComparison]) {
        self.path = path; self.status = status; self.commits = commits
        self.worktrees = worktrees; self.remotes = remotes; self.refreshedAt = Date()
    }
}
