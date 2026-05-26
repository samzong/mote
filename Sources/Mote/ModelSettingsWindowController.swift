import AppKit
import MoteCore
import SwiftUI

@MainActor
final class ModelSettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var store: ModelSettingsStore?

    func show() {
        Logger.debug("ModelSettingsWindowController.show()")
        let window = window ?? makeWindow()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let store = ModelSettingsStore()
        self.store = store

        let view = ModelSettingsView(
            store: store,
            onCancel: { [weak self] in
                self?.window?.close()
            },
            onSave: { [weak self] in
                self?.window?.close()
            }
        )
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Model Settings"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 540, height: 360)
        window.delegate = self

        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === window else {
            return
        }

        window = nil
        store = nil
    }
}
