import Foundation

public enum GitParser {
    public static func status(_ data: Data) -> GitStatus {
        let records = String(decoding: data, as: UTF8.self).split(separator: "\0", omittingEmptySubsequences: false)
        var result = GitStatus()
        var i = 0
        while i < records.count {
            let record = String(records[i]); i += 1
            if record.hasPrefix("# branch.head ") {
                result.branch = String(record.dropFirst(14))
            } else if record.hasPrefix("# branch.oid ") {
                result.head = String(record.dropFirst(13))
            } else if record.hasPrefix("# branch.upstream ") {
                result.upstream = String(record.dropFirst(18))
            } else if record.hasPrefix("? ") {
                result.files.append(FileChange(path: String(record.dropFirst(2)), status: "U", layer: .untracked))
            } else if record.hasPrefix("u ") {
                let parts = record.split(separator: " ", maxSplits: 10)
                guard parts.count == 11 else { continue }
                result.files.append(FileChange(path: String(parts[10]), status: String(parts[1]), layer: .conflicted))
            } else if record.hasPrefix("1 ") || record.hasPrefix("2 ") {
                let renamed = record.hasPrefix("2 ")
                let parts = record.split(separator: " ", maxSplits: renamed ? 9 : 8)
                var original: String?
                if renamed, i < records.count { original = String(records[i]); i += 1 }
                guard parts.count == (renamed ? 10 : 9), let path = parts.last else { continue }
                let xy = Array(parts[1])
                guard xy.count == 2 else { continue }
                if xy[0] != "." {
                    result.files.append(FileChange(path: String(path), originalPath: original, status: String(xy[0]), layer: .staged))
                }
                if xy[1] != "." {
                    result.files.append(FileChange(path: String(path), originalPath: original, status: String(xy[1]), layer: .unstaged))
                }
            }
        }
        if result.branch == "(detached)" { result.branch = "HEAD · \(result.head.prefix(7))" }
        return result
    }

    /// Six NUL-delimited fields per commit, with `git log -z` supplying the final delimiter.
    public static func commits(_ data: Data) -> [Commit] {
        let fields = String(decoding: data, as: UTF8.self).split(separator: "\0", omittingEmptySubsequences: false)
        var result: [Commit] = []
        var i = 0
        while i + 5 < fields.count {
            let sha = String(fields[i])
            guard !sha.isEmpty else { i += 1; continue }
            result.append(Commit(
                sha: sha,
                parents: fields[i + 1].split(separator: " ").map(String.init),
                author: String(fields[i + 2]),
                date: Date(timeIntervalSince1970: Double(fields[i + 3]) ?? 0),
                subject: String(fields[i + 4]),
                decorations: fields[i + 5].components(separatedBy: ", ").filter { !$0.isEmpty }
            ))
            i += 6
        }
        return result
    }

    public static func worktrees(_ data: Data) -> [Worktree] {
        let records = String(decoding: data, as: UTF8.self).split(separator: "\0", omittingEmptySubsequences: false)
        var result: [Worktree] = []
        var path: String?, branch = "分离 HEAD", bare = false, prunable = false
        func append() {
            if let path { result.append(Worktree(path: path, branch: branch, isBare: bare, isPrunable: prunable)) }
        }
        for field in records {
            if field.hasPrefix("worktree ") {
                append(); path = String(field.dropFirst(9)); branch = "分离 HEAD"; bare = false; prunable = false
            } else if field.hasPrefix("branch refs/heads/") {
                branch = String(field.dropFirst(18))
            } else if field == "bare" { bare = true }
            else if field.hasPrefix("prunable") { prunable = true }
        }
        append()
        return result
    }
}
