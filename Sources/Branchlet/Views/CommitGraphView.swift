import BranchletCore
import SwiftUI

struct CommitGraphView: View {
    let commits: [Commit]
    var limit = 160
    var compact = false
    var selectedSHA: String?
    let onSelect: (Commit) -> Void
    private var rows: [GraphRow] { Array(CommitGraph.layout(commits).prefix(limit)) }
    private var lanes: Int { max(1, rows.map(\.laneCount).max() ?? 1) }
    private var graphWidth: CGFloat { min(CGFloat(lanes) * (compact ? 13 : 17) + 16, compact ? 105 : 190) }

    var body: some View {
        if commits.isEmpty {
            ContentUnavailableView("还没有提交", systemImage: "point.3.connected.trianglepath.dotted", description: Text("提交后，历史分支图会自动出现在这里。"))
                .frame(maxWidth: .infinity, minHeight: compact ? 170 : 240)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    Button { onSelect(row.commit) } label: {
                        HStack(spacing: 6) {
                            GraphCell(row: row, lanes: lanes)
                                .frame(width: graphWidth, height: compact ? 46 : 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.commit.subject).font(.system(size: compact ? 11 : 12, weight: .medium))
                                    .foregroundStyle(.primary).lineLimit(1).truncationMode(.tail)
                                HStack(spacing: 7) {
                                    Text(row.commit.shortSHA).fontDesign(.monospaced)
                                    if row.commit.isMerge { Text("合并") }
                                    if !compact { Text(row.commit.author).lineLimit(1) }
                                    if let ref = visibleRef(row.commit) {
                                        Text(ref).lineLimit(1).truncationMode(.middle).foregroundStyle(.blue)
                                    }
                                    Spacer(minLength: 0)
                                    if !compact { Text(row.commit.date, style: .relative).lineLimit(1) }
                                }
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            .padding(.trailing, 10)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .background(selectedSHA == row.id ? Color.accentColor.opacity(0.11) : .clear)
                    }
                    .buttonStyle(.plain)
                    .help("\(row.commit.subject)\n\(row.commit.sha) · \(row.commit.author)")
                    .accessibilityLabel("\(row.commit.isMerge ? "合并提交" : "提交") \(row.commit.subject)，\(row.commit.shortSHA)")
                }
            }
        }
    }

    private func visibleRef(_ commit: Commit) -> String? {
        let ref = commit.decorations.first { $0.hasPrefix("HEAD") } ?? commit.decorations.first
        return ref?.replacingOccurrences(of: "HEAD -> ", with: "")
    }
}

private struct GraphCell: View {
    let row: GraphRow
    let lanes: Int
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Canvas { context, size in
            let step = (size.width - 16) / CGFloat(max(lanes, 1))
            func x(_ lane: Int) -> CGFloat { 10 + CGFloat(lane) * step }
            let mid = size.height / 2
            for edge in row.edges {
                var path = Path()
                switch edge.kind {
                case .incoming:
                    path.move(to: CGPoint(x: x(edge.from), y: 0))
                    path.addLine(to: CGPoint(x: x(edge.to), y: mid))
                case .outgoing:
                    path.move(to: CGPoint(x: x(edge.from), y: mid))
                    path.addCurve(to: CGPoint(x: x(edge.to), y: size.height), control1: CGPoint(x: x(edge.from), y: mid + 12), control2: CGPoint(x: x(edge.to), y: size.height - 12))
                case .passing:
                    path.move(to: CGPoint(x: x(edge.from), y: 0))
                    path.addCurve(to: CGPoint(x: x(edge.to), y: size.height), control1: CGPoint(x: x(edge.from), y: mid), control2: CGPoint(x: x(edge.to), y: mid))
                }
                context.stroke(path, with: .color(Palette.color(edge.color).opacity(0.8)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
            let radius: CGFloat = row.commit.isMerge ? 4.5 : 3.8
            let circle = Path(ellipseIn: CGRect(x: x(row.lane) - radius, y: mid - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(row.commit.isMerge ? (colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : .white) : Palette.color(row.color)))
            if row.commit.isMerge { context.stroke(circle, with: .color(Palette.color(row.color)), lineWidth: 1.6) }
        }
        .accessibilityHidden(true)
    }
}
