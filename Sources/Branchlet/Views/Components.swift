import AppKit
import BranchletCore
import SwiftUI

enum Palette {
    static let graph: [Color] = [.blue, .purple, .teal, .orange, .pink, .green, .indigo]
    static func color(_ index: Int) -> Color { graph[index % graph.count] }
    static func change(_ layer: ChangeLayer) -> Color {
        switch layer {
        case .conflicted: .red
        case .staged: .green
        case .unstaged: .orange
        case .untracked: .teal
        }
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button {
            let keyboardActivation = NSApp.currentEvent.map { $0.type == .keyDown || $0.type == .keyUp } ?? false
            action()
            if !keyboardActivation {
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
        } label: { Image(systemName: symbol).frame(width: 18, height: 18) }
            .buttonStyle(.borderless)
            .padding(5)
            .foregroundStyle(selected ? Color.accentColor : .secondary)
            .background(selected ? Color.accentColor.opacity(0.12) : .clear, in: Circle())
            .help(Text(LocalizedStringKey(label)))
            .accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

struct RepositoryPicker: View {
    var store: AppStore
    var widget = false
    var body: some View {
        Menu {
            ForEach(store.repositories) { repo in
                Button {
                    if widget { store.selectWidgetRepository(repo.id) }
                    else { store.selectRepository(repo.id) }
                } label: {
                    if repo.id == (widget ? store.widgetRepository?.id : store.selectedRepository?.id) {
                        Label(repo.name, systemImage: "checkmark")
                    } else { Text(repo.name) }
                }
            }
            Divider()
            Button("添加仓库…", systemImage: "folder.badge.plus") { store.chooseRepository() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape").foregroundStyle(.blue)
                Text((widget ? store.widgetRepository : store.selectedRepository)?.name ?? "选择仓库")
                    .font(.system(size: widget ? 12 : 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
        .menuStyle(.borderlessButton)
        .help(Text(LocalizedStringKey(widget ? "小组件固定的仓库，独立于主窗口" : "切换仓库")))
        .accessibilityLabel(Text(LocalizedStringKey(widget ? "小组件仓库" : "切换仓库")))
    }
}

struct WorktreePicker: View {
    var store: AppStore
    var widget = false
    private var snapshot: RepositorySnapshot? { widget ? store.widgetSnapshot : store.selectedSnapshot }
    private var path: String? { widget ? store.widgetPath : store.selectedPath }
    var body: some View {
        Menu {
            ForEach(snapshot?.worktrees ?? []) { tree in
                Button {
                    if widget { store.selectWidgetWorktree(tree.path) }
                    else { store.selectWorktree(tree.path) }
                } label: {
                    Text("\(tree.path == path ? "✓ " : "")\(tree.branch) — \(URL(fileURLWithPath: tree.path).lastPathComponent)")
                }
            }
        } label: {
            Label(snapshot?.status.branch ?? "读取分支…", systemImage: "arrow.triangle.branch")
                .font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
        }
        .menuStyle(.borderlessButton)
        .disabled(snapshot == nil)
        .help("切换已存在的工作树，不执行 git checkout")
        .accessibilityLabel(Text(LocalizedStringKey(widget ? "小组件工作树" : "工作树")))
    }
}

struct RemoteStrip: View {
    let snapshot: RepositorySnapshot?
    var compact = false
    var body: some View {
        if let snapshot {
            if snapshot.remotes.isEmpty {
                Text("未配置远程").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: compact ? 12 : 20) { remoteItems }
                    VStack(alignment: .leading, spacing: 5) { remoteItems }
                }
            }
        }
    }
    private var remoteItems: some View {
        ForEach(snapshot?.remotes ?? []) { remote in
            HStack(spacing: 5) {
                Text(remote.name).foregroundStyle(.secondary)
                if let ahead = remote.ahead, let behind = remote.behind {
                    Text("↑\(ahead) ↓\(behind)").monospacedDigit()
                        .foregroundStyle(behind > 0 ? Color.orange : .primary)
                } else { Text(LocalizedStringKey(remote.note ?? "未知")).foregroundStyle(.secondary) }
            }
            .font(.system(size: 11))
            .help(Text("\(remote.branch ?? remote.name) · 本地远程引用缓存，Fetch 后更新"))
        }
    }
}

struct StatusFooter: View {
    var store: AppStore
    let path: String?
    var body: some View {
        HStack(spacing: 5) {
            if let path, store.refreshing.contains(path) {
                ProgressView().controlSize(.mini)
                Text("刷新中")
            } else if let path, store.errors[path] != nil {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text("读取失败 · 显示上次结果")
            } else if let path, let date = store.snapshots[path]?.refreshedAt {
                Circle().fill(.green).frame(width: 5, height: 5)
                Text(date, style: .relative)
                Text("前更新")
            } else { Text("等待仓库") }
        }
        .font(.system(size: 10)).foregroundStyle(.secondary)
    }
}

struct RepositoryErrorView: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 11)).foregroundStyle(.orange).lineLimit(3)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}
