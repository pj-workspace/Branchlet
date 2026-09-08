import BranchletCore
import SwiftUI

struct FileListView: View {
    let files: [FileChange]
    var selection: FileChange?
    var compact = false
    let onSelect: (FileChange) -> Void
    @State private var collapsed: Set<String> = []

    var body: some View {
        if files.isEmpty {
            ContentUnavailableView("工作区干净", systemImage: "checkmark.circle", description: Text("没有待提交的文件改动。"))
                .frame(maxWidth: .infinity, minHeight: 190)
        } else {
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach(ChangeLayer.allCases, id: \.self) { layer in
                    let changes = files.filter { $0.layer == layer }
                    if !changes.isEmpty {
                        DisclosureGroup(isExpanded: binding(layer.rawValue)) {
                            if compact {
                                ForEach(changes) { file in fileRow(file) }
                            } else {
                                let groups = Dictionary(grouping: changes, by: \.directory)
                                ForEach(groups.keys.sorted(), id: \.self) { directory in
                                    if directory.isEmpty {
                                        ForEach(groups[directory] ?? []) { file in fileRow(file) }
                                    } else {
                                        DisclosureGroup(isExpanded: binding(layer.rawValue + directory)) {
                                            ForEach(groups[directory] ?? []) { file in fileRow(file) }
                                        } label: {
                                            Label(directory, systemImage: "folder")
                                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                                .lineLimit(1).truncationMode(.middle).help(directory)
                                        }
                                        .padding(.leading, 4)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(LocalizedStringKey(layer.title)).foregroundStyle(layer == .conflicted ? .red : .secondary)
                                Spacer()
                                Text("\(changes.count)").monospacedDigit().foregroundStyle(.secondary)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { !collapsed.contains(key) }, set: { expanded in
            if expanded { collapsed.remove(key) } else { collapsed.insert(key) }
        })
    }

    private func fileRow(_ file: FileChange) -> some View {
        Button { onSelect(file) } label: {
            HStack(spacing: 7) {
                Image(systemName: "doc.text").font(.system(size: 12)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    if compact && !file.directory.isEmpty {
                        Text(file.directory).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 2)
                Text(file.status).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.change(file.layer))
            }
            .padding(.horizontal, 6).padding(.vertical, compact ? 7 : 5)
            .contentShape(Rectangle())
            .background(selection?.id == file.id ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(file.originalPath.map { "\($0) → \(file.path)" } ?? file.path)
        .accessibilityLabel("\(localized(file.layer.title)), \(file.path), \(file.status)")
    }
}
