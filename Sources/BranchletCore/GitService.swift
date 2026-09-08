import Foundation

public struct GitService: Sendable {
    public let runner: GitRunner
    public init(runner: GitRunner = GitRunner()) { self.runner = runner }

    public func repositoryRoot(at path: String) async throws -> String {
        let result = try await runner.run(["rev-parse", "--show-toplevel"], at: path).checked()
        // rev-parse emits a final LF. Preserve whitespace that is actually part of the path.
        var root = result.text
        if root.hasSuffix("\n") { root.removeLast() }
        guard !root.isEmpty else { throw GitError.commandFailed("此目录不是 Git 工作区。") }
        return URL(fileURLWithPath: root).standardizedFileURL.path
    }

    public func snapshot(at path: String) async throws -> RepositorySnapshot {
        async let statusOutput = runner.run(["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all"], at: path)
        async let treeOutput = runner.run(["worktree", "list", "--porcelain", "-z"], at: path)
        async let remoteOutput = runner.run(["remote"], at: path)
        let status = GitParser.status(try await statusOutput.checked().data)
        let trees = GitParser.worktrees(try await treeOutput.checked().data).filter { !$0.isBare && !$0.isPrunable }
        let names = try await remoteOutput.checked().text.split(separator: "\n").map(String.init)
        let commits: [Commit]
        if status.isUnborn {
            commits = []
        } else {
            commits = try await history(at: path)
        }
        let remotes = await withTaskGroup(of: (Int, RemoteComparison).self) { group in
            for (index, name) in names.enumerated() {
                group.addTask { (index, await compareRemote(name, status: status, path: path)) }
            }
            var values: [(Int, RemoteComparison)] = []
            for await value in group { values.append(value) }
            return values.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return RepositorySnapshot(path: path, status: status, commits: commits, worktrees: trees, remotes: remotes)
    }

    public func history(at path: String, allBranches: Bool = false) async throws -> [Commit] {
        let output = try await runner.run([
            "log", allBranches ? "--all" : "HEAD", "--topo-order", "-n", "160", "-z",
            "--format=%H%x00%P%x00%an%x00%at%x00%s%x00%D",
        ], at: path).checked()
        return GitParser.commits(output.data)
    }

    public func diff(at path: String, change: FileChange) async throws -> String {
        if change.layer == .untracked {
            let url = URL(fileURLWithPath: path).appendingPathComponent(change.path)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                return "符号链接 → " + (try FileManager.default.destinationOfSymbolicLink(atPath: url.path))
            }
            guard values.isRegularFile == true else { return "此项目不是可预览的普通文件。" }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: 256_001) ?? Data()
            guard !data.contains(0), let text = String(data: data.prefix(256_000), encoding: .utf8) else { return "二进制或非 UTF-8 文件，无法显示文本差异。" }
            return "+++ 新文件：\(change.path)\n" + text + (data.count > 256_000 ? "\n… 预览已截断（256 KB）" : "")
        }
        var arguments = ["diff", "--no-ext-diff", "--no-textconv", "--no-color", "--unified=3"]
        if change.layer == .staged { arguments.append("--cached") }
        arguments.append("--")
        arguments.append(change.path)
        if let old = change.originalPath { arguments.append(old) }
        let output = try await runner.run(arguments, at: path, limit: 512_000)
        guard output.code == 0 else { throw GitError.commandFailed(output.error) }
        return (output.text.isEmpty ? "没有文本差异。文件可能仅修改了权限，或状态已变化。" : output.text)
            + (output.truncated ? "\n… 差异已截断（512 KB）" : "")
    }

    public func showCommit(at path: String, sha: String) async throws -> String {
        guard sha.count >= 7, sha.allSatisfy(\.isHexDigit) else { throw GitError.commandFailed("无效的提交 ID。") }
        let output = try await runner.run([
            "show", "--no-ext-diff", "--no-textconv", "--no-color", "--format=fuller",
            "--stat", "--patch", "--diff-merges=first-parent", sha, "--",
        ], at: path, limit: 512_000)
        guard output.code == 0 else { throw GitError.commandFailed(output.error) }
        return output.text + (output.truncated ? "\n… 提交差异已截断（512 KB）" : "")
    }

    public func fetch(at path: String) async throws {
        _ = try await runner.run(["-c", "credential.interactive=false", "fetch", "--all", "--no-recurse-submodules"], at: path, timeout: 60).checked()
    }

    private func compareRemote(_ name: String, status: GitStatus, path: String) async -> RemoteComparison {
        guard !status.isUnborn, !status.branch.hasPrefix("HEAD ·") else {
            return RemoteComparison(name: name, branch: nil, ahead: nil, behind: nil, note: status.isUnborn ? "尚无提交" : "分离 HEAD")
        }
        let target: String
        if let upstream = status.upstream, upstream.hasPrefix(name + "/") { target = upstream }
        else { target = "\(name)/\(status.branch)" }
        do {
            let exists = try await runner.run(["show-ref", "--verify", "--quiet", "refs/remotes/\(target)"], at: path)
            guard exists.code == 0 else {
                return RemoteComparison(name: name, branch: target, ahead: nil, behind: nil, note: "无跟踪分支")
            }
            let comparison = try await runner.run(["rev-list", "--left-right", "--count", "HEAD...refs/remotes/\(target)"], at: path).checked()
            let counts = comparison.text.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
            guard counts.count == 2 else { throw GitError.commandFailed("无法读取远程差异。") }
            return RemoteComparison(name: name, branch: target, ahead: counts[0], behind: counts[1])
        } catch {
            return RemoteComparison(name: name, branch: target, ahead: nil, behind: nil, note: "读取失败")
        }
    }
}
