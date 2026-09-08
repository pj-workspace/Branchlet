import Foundation
import Testing
@testable import BranchletCore

@Test func stagedAndUnstagedAreIndependent() {
    let input = "# branch.oid abc123\0# branch.head main\01 MM N... 100644 100644 100644 abc def file with spaces.swift\0? 新文件.txt\0"
    let status = GitParser.status(Data(input.utf8))
    #expect(status.branch == "main")
    #expect(status.changedFileCount == 2)
    #expect(status.files.count == 3)
    #expect(status.files.filter { $0.path == "file with spaces.swift" }.map(\.layer) == [.staged, .unstaged])
}

@Test func renameConsumesOriginalPathWithoutParsingItAsStatus() {
    let input = "2 R. N... 100644 100644 100644 abc def R100 new\nname.txt\0? original\tname.txt\0? next.txt\0"
    let status = GitParser.status(Data(input.utf8))
    #expect(status.files.count == 2)
    #expect(status.files[0].path == "new\nname.txt")
    #expect(status.files[0].originalPath == "? original\tname.txt")
    #expect(status.files[1].path == "next.txt")
}

@Test func conflictsAndDetachedHeadAreExplicit() {
    let input = "# branch.oid 1234567890\0# branch.head (detached)\0u UU N... 100644 100644 100644 100644 a b c conflict.txt\0"
    let status = GitParser.status(Data(input.utf8))
    #expect(status.branch == "HEAD · 1234567")
    #expect(status.hasConflicts)
    #expect(status.files.first?.layer == .conflicted)
}

@Test func worktreesPreserveWhitespaceAndFlags() {
    let input = "worktree /tmp/main repo\0HEAD abc\0branch refs/heads/main\0\0worktree /tmp/feature\nrepo\0HEAD def\0branch refs/heads/feature/demo\0prunable gitdir file points to non-existent location\0\0"
    let trees = GitParser.worktrees(Data(input.utf8))
    #expect(trees.count == 2)
    #expect(trees[0].branch == "main")
    #expect(trees[1].path == "/tmp/feature\nrepo")
    #expect(trees[1].isPrunable)
}

@Test func graphKeepsAllMergeParentsAndConverges() {
    func commit(_ sha: String, _ parents: [String]) -> Commit {
        Commit(sha: sha, parents: parents, author: "Test", date: Date(), subject: sha)
    }
    let rows = CommitGraph.layout([
        commit("merge", ["main", "topic", "third"]),
        commit("topic", ["root"]), commit("third", ["root"]),
        commit("main", ["root"]), commit("root", []),
    ])
    #expect(rows[0].edges.filter { $0.kind == .outgoing }.count == 3)
    #expect(Set(rows[0].edges.filter { $0.kind == .outgoing }.map(\.to)).count == 3)
    #expect(rows.last?.edges.contains { $0.kind == .outgoing } == false)
    for row in rows {
        #expect(row.lane < row.laneCount)
        #expect(row.edges.allSatisfy { $0.from < row.laneCount && $0.to < row.laneCount })
    }
}
