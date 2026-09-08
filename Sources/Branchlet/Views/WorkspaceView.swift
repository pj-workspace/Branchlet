import BranchletCore
import SwiftUI

struct WorkspaceView: View {
    @Bindable var store: AppStore
    private var selectedFile: FileChange? {
        if case .file(let file) = store.detailSelection { return file }
        return nil
    }
    private var selectedSHA: String? {
        if case .commit(let commit) = store.detailSelection { return commit.sha }
        return nil
    }

    var body: some View {
        HSplitView {
            sidebar.frame(minWidth: 185, idealWidth: 215, maxWidth: 280)
            VStack(spacing: 0) {
                if let repository = store.selectedRepository {
                    header(repository)
                    if let path = store.selectedPath, let error = store.errors[path] { RepositoryErrorView(message: error).padding(10) }
                    HSplitView {
                        ScrollView {
                            if let snapshot = store.selectedSnapshot {
                                FileListView(files: snapshot.status.files, selection: selectedFile) { file in store.showDetail(.file(file)) }
                            } else { ProgressView("读取文件…").padding(30) }
                        }
                        .frame(minWidth: 240, idealWidth: 290, maxWidth: 430)
                        .background(Color(nsColor: .controlBackgroundColor))
                        VSplitView {
                            VStack(spacing: 0) {
                                HStack {
                                    Label("提交历史", systemImage: "arrow.triangle.branch").fontWeight(.medium)
                                    Spacer()
                                    Text("当前工作树 · 最近 160 条").foregroundStyle(.secondary)
                                }
                                .font(.system(size: 11)).padding(12)
                                Divider()
                                ScrollView {
                                    CommitGraphView(commits: store.selectedSnapshot?.commits ?? [], selectedSHA: selectedSHA) { commit in store.showDetail(.commit(commit)) }
                                }
                            }
                            .frame(minHeight: 180)
                            if let selection = store.detailSelection {
                                VStack(spacing: 0) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selection.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                            Text(selection.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                        Spacer()
                                        if store.detailLoading { ProgressView().controlSize(.small) }
                                        IconButton(symbol: "xmark", label: "关闭详情") { store.clearDetail() }
                                    }.padding(12)
                                    Divider()
                                    DiffTextView(text: store.detailText).id(selection)
                                }
                                .frame(minHeight: 180, idealHeight: 280)
                            }
                        }
                        .frame(minWidth: 340)
                        .background(Color(nsColor: .textBackgroundColor))
                    }
                    HStack {
                        StatusFooter(store: store, path: store.selectedPath)
                        Spacer()
                        if let path = store.selectedPath, let date = store.fetchedAt[path] {
                            Text("Fetch：\(date.formatted(date: .omitted, time: .shortened))")
                        } else { Text("远程状态来自本地引用缓存 · 点 Fetch 更新") }
                    }
                    .font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 10)
                } else {
                    ContentUnavailableView {
                        Label("把 Git 放在手边", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("选择本地仓库。Branchlet 会读取文件改动、提交历史和远程分支状态。")
                    } actions: {
                        Button("添加仓库…", systemImage: "folder.badge.plus") { store.chooseRepository() }.buttonStyle(.glassProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 850, minHeight: 520)
        .alert("Branchlet", isPresented: Binding(get: { store.appError != nil }, set: { if !$0 { store.appError = nil } })) {
            Button("好") { store.appError = nil }
        } message: { Text(store.appError ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted").foregroundStyle(.blue)
                Text("Branchlet").font(.system(size: 15, weight: .semibold))
                Spacer()
            }.padding(.horizontal, 17).padding(.top, 16).padding(.bottom, 22)
            Text("仓库").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 17).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(store.repositories) { repository in
                        Button { store.selectRepository(repository.id) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder").foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(repository.name).font(.system(size: 12, weight: .medium)).lineLimit(2).truncationMode(.middle)
                                    if let snapshot = store.snapshots[repository.path] {
                                        Text("\(snapshot.worktrees.count) 个工作树").font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                if let count = store.snapshots[repository.path]?.status.changedFileCount {
                                    Text(count == 0 ? "✓" : "\(count)").font(.system(size: 11)).foregroundStyle(count == 0 ? Color.secondary : .orange)
                                }
                            }
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(repository.id == store.selectedRepository?.id ? Color.accentColor.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("在 Finder 中显示", systemImage: "folder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.path) }
                            Button("从列表移除", systemImage: "minus.circle") { store.removeRepository(repository) }
                        }
                        .help(repository.path)
                    }
                }.padding(.horizontal, 8)
            }
            Spacer(minLength: 15)
            Divider().padding(.horizontal, 14)
            Button("添加仓库…", systemImage: "plus") { store.chooseRepository() }
                .buttonStyle(.borderless).font(.system(size: 12)).padding(16)
        }
        .background(.regularMaterial)
    }

    private func header(_ repository: Repository) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(repository.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(store.selectedPath ?? repository.path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button("浮动图", systemImage: "pip.enter") { WindowCoordinator.shared.showWidget() }.buttonStyle(.glass)
                Button("Fetch", systemImage: "arrow.triangle.2.circlepath") { store.fetchSelected() }
                    .buttonStyle(.glass).disabled(store.selectedPath.map { store.fetching.contains($0) } ?? true)
                    .help("获取所有远程的最新引用，不合并、不推送")
                IconButton(symbol: "arrow.clockwise", label: "刷新本地状态") {
                    if let path = store.selectedPath { Task { await store.refresh(path) } }
                }
            }
            HStack {
                WorktreePicker(store: store).frame(maxWidth: 280)
                Spacer()
                RemoteStrip(snapshot: store.selectedSnapshot)
            }
        }
        .padding(16)
    }
}
