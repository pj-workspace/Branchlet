# Branchlet

A native macOS Git companion. A menu bar glance, a full repository inspector, and a floating commit graph that stays with you.

原生 macOS Git 看板：菜单栏快览、完整仓库窗口、常驻浮动分支图。

## Development

Requires macOS 26+, Xcode 26+ and Swift 6.2+. No third-party dependencies.

```sh
swift test
./scripts/build-app.sh
open dist/Branchlet.app
```

## Scope

- Real local Git status, including staged, unstaged, untracked and conflicted files.
- Commit graph, file diffs, commit details and worktree selection.
- Separate ahead/behind comparisons for each configured remote, including GitHub and Codeup.
- A floating widget pinned to its own repository and worktree.
- System Liquid Glass controls and native AppKit windows.

Branchlet observes repositories. It does not stage, commit, reset, merge or push. Remote refresh uses an explicit `git fetch`; locally cached remote references are labeled as such.

Repository paths and preferences stay on your Mac. No analytics, account service or hosted backend.

## License

MIT
