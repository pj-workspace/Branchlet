import BranchletCore
import SwiftUI

struct FloatingWidgetView: View {
    @Bindable var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundStyle(.tertiary)
                    .overlay { WindowDragHandle().help("拖动小组件") }
                    .frame(width: 15, height: 26)
                RepositoryPicker(store: store, widget: true)
                IconButton(symbol: store.preferences.widgetPinned ? "pin.fill" : "pin", label: "置顶", selected: store.preferences.widgetPinned) {
                    store.preferences.widgetPinned.toggle(); store.save(); WindowCoordinator.shared.updateWidget()
                }
                IconButton(symbol: store.preferences.widgetCollapsed ? "chevron.down" : "minus", label: store.preferences.widgetCollapsed ? "展开小组件" : "收起小组件") {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { store.preferences.widgetCollapsed.toggle() }
                    store.save(); WindowCoordinator.shared.updateWidget()
                }
                IconButton(symbol: "xmark", label: "关闭小组件") { WindowCoordinator.shared.closeWidget() }
            }
            .padding(.horizontal, 10).padding(.top, 11).padding(.bottom, 6)

            if store.widgetRepository != nil {
                WorktreePicker(store: store, widget: true).padding(.horizontal, 18).padding(.bottom, 11)
                if store.preferences.widgetCollapsed {
                    HStack {
                        Text("\(store.widgetSnapshot?.status.changedFileCount ?? 0) 个文件有改动")
                        Spacer()
                        Button("展开窗口", systemImage: "arrow.up.right") { store.openWidgetInMain() }.buttonStyle(.borderless)
                    }
                    .font(.system(size: 11)).padding(.horizontal, 17)
                } else {
                    expandedContent
                }
            } else {
                Spacer()
                Button("添加 Git 仓库…", systemImage: "folder.badge.plus") { store.chooseRepository() }.buttonStyle(.glass)
                Spacer()
            }
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 24))
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(5)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach([ChangeLayer.unstaged, .staged, .untracked], id: \.self) { layer in
                    Button { store.openWidgetInMain() } label: {
                        HStack(spacing: 6) {
                            Text(layer.title).foregroundStyle(.secondary)
                            Text("\(store.widgetSnapshot?.status.files.filter { $0.layer == layer }.count ?? 0)").fontWeight(.semibold).monospacedDigit()
                        }
                        .font(.system(size: 11)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 11)).padding(.horizontal, 12)

            HStack { RemoteStrip(snapshot: store.widgetSnapshot, compact: true); Spacer(minLength: 0) }
                .padding(.horizontal, 17).padding(.vertical, 12)

            if store.widgetSnapshot?.status.hasConflicts == true {
                Label("存在合并冲突", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.red).padding(.bottom, 6)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("提交历史").fontWeight(.medium)
                    Spacer()
                    Text("最近 5 条").foregroundStyle(.secondary)
                }
                .font(.system(size: 11)).padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)
                if let snapshot = store.widgetSnapshot {
                    CommitGraphView(commits: snapshot.commits, limit: 5, compact: true) { commit in store.openWidgetInMain(commit: commit) }
                } else { ProgressView("读取提交图…").frame(maxWidth: .infinity, minHeight: 200) }
            }
            .padding(.bottom, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.96), in: RoundedRectangle(cornerRadius: 15))
            .padding(.horizontal, 8)

            if let path = store.widgetPath, let error = store.errors[path] {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2).padding(.horizontal, 14).padding(.top, 6)
            }

            HStack(spacing: 5) {
                StatusFooter(store: store, path: store.widgetPath)
                Spacer(minLength: 0)
                Button("完整历史", systemImage: "arrow.up.right") { store.openWidgetInMain() }
                    .font(.system(size: 11)).buttonStyle(.borderless)
            }
            .padding(.horizontal, 16).padding(.top, 12)
            HStack {
                Text(store.preferences.widgetPinned ? "已置顶 · 固定此仓库" : "固定此仓库")
                Spacer()
                Text("远程：本地缓存")
            }
            .font(.system(size: 9)).foregroundStyle(.tertiary).padding(.horizontal, 16).padding(.top, 6)
        }
    }
}
