import AppKit
import BranchletCore
import Observation

struct AppPreferences: Codable {
    var repositories: [Repository] = []
    var selectedRepository: String?
    var worktreeSelections: [String: String] = [:]
    var widgetRepository: String?
    var widgetPath: String?
    var widgetVisible = false
    var widgetPinned = true
    var widgetCollapsed = false
}

enum DetailSelection: Hashable {
    case file(FileChange)
    case commit(Commit)
    var title: String {
        switch self {
        case .file(let file): file.name
        case .commit(let commit): commit.subject
        }
    }
    var subtitle: String {
        switch self {
        case .file(let file): "\(file.layer.title) · \(file.path)"
        case .commit(let commit): "\(commit.shortSHA) · \(commit.author)"
        }
    }
}

@MainActor @Observable
final class AppStore {
    static let shared = AppStore()
    var preferences: AppPreferences
    var snapshots: [String: RepositorySnapshot] = [:]
    var errors: [String: String] = [:]
    var refreshing: Set<String> = []
    var fetching: Set<String> = []
    var fetchedAt: [String: Date] = [:]
    var appError: String?
    var detailSelection: DetailSelection?
    var detailText = ""
    var detailLoading = false
    var menuTab = 0
    @ObservationIgnored let git = GitService()
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var detailGeneration = 0
    @ObservationIgnored private let configURL: URL

    var repositories: [Repository] { preferences.repositories }
    var selectedRepository: Repository? { repositories.first { $0.id == preferences.selectedRepository } ?? repositories.first }
    var selectedPath: String? {
        guard let repo = selectedRepository else { return nil }
        return preferences.worktreeSelections[repo.id] ?? repo.path
    }
    var selectedSnapshot: RepositorySnapshot? { selectedPath.flatMap { snapshots[$0] } }
    var widgetRepository: Repository? { repositories.first { $0.id == preferences.widgetRepository } }
    var widgetPath: String? { preferences.widgetPath ?? widgetRepository?.path }
    var widgetSnapshot: RepositorySnapshot? { widgetPath.flatMap { snapshots[$0] } }
    var menuCount: Int { selectedSnapshot?.status.changedFileCount ?? 0 }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Branchlet", isDirectory: true)
        configURL = base.appendingPathComponent("preferences.json")
        if let data = try? Data(contentsOf: configURL), let saved = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = saved
        } else { preferences = AppPreferences() }
    }

    func start() async {
        guard pollTask == nil else { return }
        for repository in repositories { await refresh(repository.path) }
        pollTask = Task { [weak self] in
            var cycle = 0
            while !Task.isCancelled {
                guard let self else { return }
                var paths = Set([self.selectedPath, self.preferences.widgetVisible ? self.widgetPath : nil].compactMap { $0 })
                if cycle % 12 == 0 { paths.formUnion(self.repositories.map(\.path)) }
                for path in paths { await self.refresh(path) }
                cycle += 1
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    func chooseRepository() {
        let panel = NSOpenPanel()
        panel.title = "添加 Git 仓库"
        panel.message = "选择本机已克隆的仓库目录。"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { for url in urls { await addRepository(url.path) } }
    }

    func addRepository(_ path: String) async {
        do {
            let root = try await git.repositoryRoot(at: path)
            let repo = Repository(path: root)
            if !repositories.contains(repo) { preferences.repositories.append(repo) }
            preferences.selectedRepository = repo.id
            if preferences.widgetRepository == nil {
                preferences.widgetRepository = repo.id; preferences.widgetPath = root
            }
            clearDetail(); save()
            await refresh(root)
        } catch { appError = error.localizedDescription }
    }

    func removeRepository(_ repository: Repository) {
        preferences.repositories.removeAll { $0.id == repository.id }
        preferences.worktreeSelections.removeValue(forKey: repository.id)
        if preferences.selectedRepository == repository.id { preferences.selectedRepository = repositories.first?.id }
        if preferences.widgetRepository == repository.id {
            preferences.widgetRepository = repositories.first?.id
            preferences.widgetPath = repositories.first?.path
        }
        clearDetail(); save()
    }

    func selectRepository(_ id: String) {
        preferences.selectedRepository = id; clearDetail(); save()
        if let path = selectedPath { Task { await refresh(path) } }
    }

    func selectWorktree(_ path: String) {
        guard let repo = selectedRepository else { return }
        preferences.worktreeSelections[repo.id] = path; clearDetail(); save()
        Task { await refresh(path) }
    }

    func selectWidgetRepository(_ id: String) {
        preferences.widgetRepository = id
        preferences.widgetPath = repositories.first { $0.id == id }?.path
        save()
        if let path = widgetPath { Task { await refresh(path) } }
    }

    func selectWidgetWorktree(_ path: String) {
        preferences.widgetPath = path; save()
        Task { await refresh(path) }
    }

    func openWidgetInMain(commit: Commit? = nil) {
        guard let repo = widgetRepository, let path = widgetPath else { return }
        preferences.selectedRepository = repo.id; preferences.worktreeSelections[repo.id] = path
        clearDetail(); save()
        WindowCoordinator.shared.showMain()
        if let commit { showDetail(.commit(commit)) }
    }

    func refresh(_ path: String) async {
        guard !refreshing.contains(path) else { return }
        refreshing.insert(path)
        defer { refreshing.remove(path) }
        do {
            let snapshot = try await git.snapshot(at: path)
            snapshots[path] = snapshot; errors.removeValue(forKey: path)
            if selectedPath == path, let detailSelection {
                if case .file(let file) = detailSelection, !snapshot.status.files.contains(where: { $0.id == file.id }) { clearDetail() }
                else { showDetail(detailSelection, background: true) }
            }
        } catch { errors[path] = error.localizedDescription }
    }

    func fetchSelected() {
        guard let path = selectedPath, !fetching.contains(path) else { return }
        fetching.insert(path)
        Task {
            defer { fetching.remove(path) }
            do {
                try await git.fetch(at: path)
                fetchedAt[path] = Date()
                await refresh(path)
            } catch { errors[path] = error.localizedDescription }
        }
    }

    func clearDetail() {
        detailGeneration += 1; detailSelection = nil; detailText = ""; detailLoading = false
    }

    func showDetail(_ selection: DetailSelection, background: Bool = false) {
        guard let path = selectedPath else { return }
        detailSelection = selection; detailGeneration += 1
        let generation = detailGeneration
        if !background { detailLoading = true; detailText = "" }
        Task {
            do {
                let text: String
                switch selection {
                case .file(let file): text = try await git.diff(at: path, change: file)
                case .commit(let commit): text = try await git.showCommit(at: path, sha: commit.sha)
                }
                guard generation == detailGeneration, selectedPath == path else { return }
                detailText = text; detailLoading = false
            } catch {
                guard generation == detailGeneration else { return }
                detailText = error.localizedDescription; detailLoading = false
            }
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: configURL, options: .atomic)
        } catch { appError = "设置保存失败：\(error.localizedDescription)" }
    }
}
