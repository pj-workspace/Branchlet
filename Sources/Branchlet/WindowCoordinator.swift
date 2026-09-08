import AppKit
import SwiftUI

@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = WindowCoordinator()
    private var mainWindow: NSWindow?
    private var widgetPanel: FloatingPanel?

    func showMain() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1100, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.title = "Branchlet"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.minSize = NSSize(width: 850, height: 560)
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: WorkspaceView(store: AppStore.shared))
            window.setContentSize(NSSize(width: 1120, height: 740))
            window.center()
            window.setFrameAutosaveName("Branchlet.Main")
            window.setFrameUsingName("Branchlet.Main")
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        mainWindow?.makeFirstResponder(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showWidget(activate: Bool = true) {
        let store = AppStore.shared
        if store.widgetRepository == nil, let repo = store.selectedRepository {
            store.preferences.widgetRepository = repo.id
            store.preferences.widgetPath = store.selectedPath
        }
        store.preferences.widgetVisible = true; store.save()
        if widgetPanel == nil {
            let panel = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 354, height: widgetHeight),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
            )
            panel.title = localized("Branchlet 浮动分支图")
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.contentViewController = NSHostingController(rootView: FloatingWidgetView(store: store))
            if let screen = NSScreen.main {
                panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 374, y: screen.visibleFrame.maxY - widgetHeight - 24))
            }
            panel.setFrameAutosaveName("Branchlet.Widget")
            panel.setFrameUsingName("Branchlet.Widget")
            widgetPanel = panel
        }
        updateWidget()
        if activate {
            widgetPanel?.makeKeyAndOrderFront(nil)
            widgetPanel?.makeFirstResponder(nil)
        }
        else { widgetPanel?.orderFrontRegardless() }
    }

    func updateWidget() {
        guard let panel = widgetPanel else { return }
        panel.level = AppStore.shared.preferences.widgetPinned ? .floating : .normal
        var frame = panel.frame
        frame.origin.y = frame.maxY - widgetHeight
        frame.size = NSSize(width: 354, height: widgetHeight)
        // A saved panel frame can belong to a disconnected or rearranged display.
        let screen = NSScreen.screens.max { left, right in
            let a = frame.intersection(left.visibleFrame)
            let b = frame.intersection(right.visibleFrame)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }.flatMap { frame.intersects($0.visibleFrame) ? $0 : nil } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        panel.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    func closeWidget() { widgetPanel?.close() }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === widgetPanel else { return }
        AppStore.shared.preferences.widgetVisible = false; AppStore.shared.save()
    }

    private var widgetHeight: CGFloat { AppStore.shared.preferences.widgetCollapsed ? 128 : 520 }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    }
}
