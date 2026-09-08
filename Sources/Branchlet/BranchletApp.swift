import AppKit
import SwiftUI

@main
struct BranchletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = AppStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.selectedSnapshot?.status.hasConflicts == true ? "exclamationmark.triangle" : "point.3.connected.trianglepath.dotted")
                if store.menuCount > 0 { Text("\(store.menuCount)").monospacedDigit() }
            }
            .accessibilityLabel("Branchlet，\(store.menuCount) 个文件有改动")
        }
        .menuBarExtraStyle(.window)

        Settings { PreferencesView(store: store) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task {
            let store = AppStore.shared
            let arguments = ProcessInfo.processInfo.arguments
            if let i = arguments.firstIndex(of: "--repository"), i + 1 < arguments.count {
                await store.addRepository(arguments[i + 1])
            }
            await store.start()
            if store.repositories.isEmpty || arguments.contains("--show-main") { WindowCoordinator.shared.showMain() }
            if store.preferences.widgetVisible || arguments.contains("--show-widget") { WindowCoordinator.shared.showWidget() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowCoordinator.shared.showMain(); return true
    }
}
