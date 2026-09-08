import SwiftUI

struct MenuBarView: View {
    @Bindable var store: AppStore
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RepositoryPicker(store: store)
                IconButton(symbol: "arrow.clockwise", label: "刷新本地状态") {
                    if let path = store.selectedPath { Task { await store.refresh(path) } }
                }
            }
            .padding(16)
            if store.selectedRepository != nil {
                VStack(alignment: .leading, spacing: 10) {
                    WorktreePicker(store: store)
                    RemoteStrip(snapshot: store.selectedSnapshot)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 17).padding(.bottom, 13)
                if let path = store.selectedPath, let error = store.errors[path] { RepositoryErrorView(message: error).padding(.horizontal, 10) }
                Picker("查看内容", selection: $store.menuTab) {
                    Text("更改 · \(store.menuCount)").tag(0)
                    Text("分支图").tag(1)
                }
                .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 14).padding(.bottom, 10)
                ScrollView {
                    if let snapshot = store.selectedSnapshot {
                        if store.menuTab == 0 {
                            FileListView(files: snapshot.status.files, compact: true) { file in
                                store.showDetail(.file(file)); WindowCoordinator.shared.showMain()
                            }
                        } else {
                            CommitGraphView(commits: snapshot.commits, limit: 25) { commit in
                                store.showDetail(.commit(commit)); WindowCoordinator.shared.showMain()
                            }
                            .padding(.vertical, 5)
                        }
                    } else { ProgressView("读取仓库…").frame(maxWidth: .infinity, minHeight: 200) }
                }
                .frame(height: 325)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 8)
            } else {
                ContentUnavailableView {
                    Label("把 Git 放在手边", systemImage: "arrow.triangle.branch")
                } description: { Text("添加本地仓库，随时查看文件改动与提交历史。") }
                actions: { Button("添加仓库…", systemImage: "folder.badge.plus") { store.chooseRepository() }.buttonStyle(.glassProminent) }
                .frame(height: 245)
            }
            HStack {
                StatusFooter(store: store, path: store.selectedPath)
                Spacer(minLength: 4)
                Button("浮动图", systemImage: "pip.enter") { WindowCoordinator.shared.showWidget() }
                    .help("打开独立的常驻浮动分支图")
                Button("完整窗口", systemImage: "arrow.up.left.and.arrow.down.right") { WindowCoordinator.shared.showMain() }
            }
            .font(.system(size: 11)).buttonStyle(.borderless).padding(14)
            Divider().padding(.horizontal, 12)
            HStack {
                SettingsLink { Label("设置", systemImage: "gearshape") }
                Spacer()
                Button("退出 Branchlet") { NSApp.terminate(nil) }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary).buttonStyle(.borderless).padding(.horizontal, 15).padding(.vertical, 10)
        }
        .frame(width: 460)
        .alert("Branchlet", isPresented: Binding(get: { store.appError != nil }, set: { if !$0 { store.appError = nil } })) {
            Button("好") { store.appError = nil }
        } message: { Text(store.appError ?? "") }
    }
}
