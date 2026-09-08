import Foundation

public enum GraphEdgeKind: Sendable { case incoming, outgoing, passing }

public struct GraphEdge: Sendable {
    public let from: Int
    public let to: Int
    public let color: Int
    public let kind: GraphEdgeKind
}

public struct GraphRow: Identifiable, Sendable {
    public var id: String { commit.sha }
    public let commit: Commit
    public let lane: Int
    public let color: Int
    public let edges: [GraphEdge]
    public let laneCount: Int
}

/// Parent-driven lane layout, including merges and commits whose parents fall outside the loaded page.
public enum CommitGraph {
    private struct Lane { let sha: String; let color: Int }

    public static func layout(_ commits: [Commit]) -> [GraphRow] {
        var lanes: [Lane] = []
        var nextColor = 0
        var result: [GraphRow] = []
        for commit in commits {
            let existed = lanes.contains { $0.sha == commit.sha }
            if !existed { lanes.append(Lane(sha: commit.sha, color: nextColor)); nextColor += 1 }
            let before = lanes
            guard let index = before.firstIndex(where: { $0.sha == commit.sha }) else { continue }
            let color = before[index].color
            lanes.remove(at: index)
            for (p, parent) in commit.parents.enumerated() where !lanes.contains(where: { $0.sha == parent }) {
                let parentColor = p == 0 ? color : nextColor
                if p > 0 { nextColor += 1 }
                lanes.insert(Lane(sha: parent, color: parentColor), at: min(index + p, lanes.count))
            }
            var edges: [GraphEdge] = []
            if existed { edges.append(GraphEdge(from: index, to: index, color: color, kind: .incoming)) }
            for (i, track) in before.enumerated() where track.sha != commit.sha {
                if let j = lanes.firstIndex(where: { $0.sha == track.sha }) {
                    edges.append(GraphEdge(from: i, to: j, color: track.color, kind: .passing))
                }
            }
            for parent in commit.parents {
                if let j = lanes.firstIndex(where: { $0.sha == parent }) {
                    edges.append(GraphEdge(from: index, to: j, color: lanes[j].color, kind: .outgoing))
                }
            }
            result.append(GraphRow(commit: commit, lane: index, color: color, edges: edges, laneCount: max(before.count, lanes.count)))
        }
        return result
    }
}
