import AppKit
import SwiftUI

/// Native selectable, read-only text with horizontal scrolling and bounded input from GitService.
struct DiffTextView: NSViewRepresentable {
    let text: String
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true; scroll.borderType = .noBorder
        let view = NSTextView()
        view.isEditable = false; view.isSelectable = true; view.isRichText = true
        view.isHorizontallyResizable = true; view.isVerticallyResizable = true
        view.minSize = .zero; view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.autoresizingMask = [.width]
        view.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = false
        view.textContainerInset = NSSize(width: 12, height: 12)
        view.backgroundColor = .textBackgroundColor
        view.setAccessibilityLabel("Git 差异，只读文本")
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard context.coordinator.lastText != text, let view = scroll.documentView as? NSTextView else { return }
        context.coordinator.lastText = text
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.textColor,
        ])
        let string = text as NSString
        var location = 0
        while location < string.length {
            let range = string.lineRange(for: NSRange(location: location, length: 0))
            let line = string.substring(with: range)
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                attributed.addAttributes([.foregroundColor: NSColor.systemGreen, .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.08)], range: range)
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                attributed.addAttributes([.foregroundColor: NSColor.systemRed, .backgroundColor: NSColor.systemRed.withAlphaComponent(0.08)], range: range)
            } else if line.hasPrefix("@@") || line.hasPrefix("diff --git") {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
            }
            location = NSMaxRange(range)
        }
        view.textStorage?.setAttributedString(attributed)
    }

    final class Coordinator { var lastText: String? }
}
