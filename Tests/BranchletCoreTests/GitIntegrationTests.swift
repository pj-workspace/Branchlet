import Foundation
import Testing
@testable import BranchletCore

private struct Fixture {
    let url: URL
    let service = GitService()
    var path: String { url.path }
    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("branchlet-test \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func clean() { try? FileManager.default.removeItem(at: url) }
    @discardableResult func git(_ args: [String]) async throws -> GitOutput { try await service.runner.run(args, at: path).checked() }
    func initialize() async throws {
        try await git(["init", "-b", "main"])
        try await git(["config", "user.name", "Branchlet Tests"])
        try await git(["config", "user.email", "tests@example.invalid"])
        try await git(["config", "commit.gpgsign", "false"])
        try await git(["config", "core.hooksPath", "/dev/null"])
    }
    func write(_ name: String, _ text: String) throws { try text.write(to: url.appendingPathComponent(name), atomically: true, encoding: .utf8) }
    func commit(_ message: String) async throws {
        try await git(["add", "--all"])
        try await git(["commit", "-m", message])
    }
}

@Test func realRepositoryRoundTripAndLiteralPaths() async throws {
    let f = try Fixture(); defer { f.clean() }
    try await f.initialize()
    let empty = try await f.service.snapshot(at: f.path)
    #expect(empty.status.isUnborn)
    #expect(empty.commits.isEmpty)
    let name = "special [name]\n你好.txt"
    try f.write(name, "original\n")
    try await f.commit("Initial commit")
    try f.write(name, "staged value\n")
    try await f.git(["add", "--", name])
    try f.write(name, "working value\n")
    try f.write("untracked.txt", "not committed\n")
    let snapshot = try await f.service.snapshot(at: f.path)
    #expect(snapshot.commits.count == 1)
    #expect(snapshot.commits[0].subject == "Initial commit")
    #expect(snapshot.commits[0].decorations.contains { $0.contains("main") })
    #expect(snapshot.status.changedFileCount == 2)
    let staged = try #require(snapshot.status.files.first { $0.layer == .staged })
    let unstaged = try #require(snapshot.status.files.first { $0.layer == .unstaged })
    let stagedDiff = try await f.service.diff(at: f.path, change: staged)
    let workingDiff = try await f.service.diff(at: f.path, change: unstaged)
    #expect(stagedDiff.contains("+staged value"))
    #expect(!stagedDiff.contains("working value"))
    #expect(workingDiff.contains("+working value"))
    #expect(try await f.service.repositoryRoot(at: f.path) == f.url.resolvingSymlinksInPath().path)
}

@Test func realMergeGraphWorktreeAndCommitDetails() async throws {
    let f = try Fixture(); defer { f.clean() }
    try await f.initialize()
    try f.write("base", "base\n"); try await f.commit("base")
    try await f.git(["switch", "-c", "feature"])
    try f.write("feature", "new\n"); try await f.commit("feature")
    try await f.git(["switch", "main"])
    try f.write("main", "main\n"); try await f.commit("main")
    let currentHistory = try await f.service.history(at: f.path)
    let allHistory = try await f.service.history(at: f.path, allBranches: true)
    #expect(currentHistory.count == 2)
    #expect(allHistory.count == 3)
    #expect(allHistory.contains { $0.subject == "feature" })
    try await f.git(["merge", "--no-ff", "feature", "-m", "merge feature"])
    let treePath = f.url.appendingPathComponent("linked tree").path
    try await f.git(["worktree", "add", treePath, "feature"])
    let snapshot = try await f.service.snapshot(at: f.path)
    #expect(snapshot.commits.count == 4)
    #expect(snapshot.commits[0].parents.count == 2)
    #expect(snapshot.worktrees.count == 2)
    let other = try await f.service.snapshot(at: treePath)
    #expect(other.status.branch == "feature")
    #expect(other.commits[0].subject == "feature")
    let detail = try await f.service.showCommit(at: f.path, sha: snapshot.commits[0].sha)
    #expect(detail.contains("merge feature"))
    #expect(detail.contains("+new"))
}

@Test func twoRemotesHaveIndependentAheadCounts() async throws {
    let f = try Fixture(); defer { f.clean() }
    try await f.initialize()
    for name in ["origin", "codeup"] {
        let remotePath = f.url.appendingPathComponent("\(name).git").path
        try await f.git(["init", "--bare", remotePath])
        try await f.git(["remote", "add", name, remotePath])
    }
    try f.write(".gitignore", "*.git/\n")
    try f.write("file", "one\n"); try await f.commit("first")
    try await f.git(["push", "origin", "main"])
    try await f.git(["push", "codeup", "main"])
    try f.write("file", "two\n"); try await f.commit("second")
    try await f.git(["push", "origin", "main"])
    let snapshot = try await f.service.snapshot(at: f.path)
    #expect(snapshot.remotes.first { $0.name == "origin" }?.ahead == 0)
    #expect(snapshot.remotes.first { $0.name == "codeup" }?.ahead == 1)
    #expect(snapshot.remotes.allSatisfy { $0.behind == 0 })
}
