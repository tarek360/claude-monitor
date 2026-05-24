import AppKit
import Foundation
import Network
import SwiftUI

// MARK: - Panel (key-accepting so buttons inside work)

private final class StatusPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let server = StatusLineServer()
    let model  = UsageViewModel()

    private var panel: StatusPanel?
    private var hostingView: NSHostingView<PopoverView>?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil  // track system light/dark mode
        setupStatusItem()
        buildPanel()
        server.onPost = { [weak self] data in self?.model.update(from: data) }
        server.start()
    }

    // MARK: - Status Item

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let btn = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Monitor")
        img?.isTemplate = true
        btn.image = img
        btn.action = #selector(statusItemClicked)
        btn.target = self
        btn.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    // MARK: - Panel setup

    private static let githubURL = URL(string: "https://github.com/tarek/claude-monitor")!

    func buildPanel() {
        let content = PopoverView(
            model: model,
            onGitHub: { NSWorkspace.shared.open(AppDelegate.githubURL) },
            onQuit: { [weak self] in self?.quitAll() }
        )

        // Native popover material — auto-adapts to light/dark
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        // No autoresizingMask — we manage the frame explicitly in showPanel()
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 300)
        effect.frame = hosting.frame
        effect.addSubview(hosting)
        hostingView = hosting

        let p = StatusPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.contentView = effect

        panel = p
    }

    // MARK: - Show / hide

    @objc func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseDown {
            showControlMenu()
        } else {
            panel?.isVisible == true ? hidePanel() : showPanel()
        }
    }

    func showPanel() {
        guard let panel, let hosting = hostingView,
              let btn = statusItem.button, let btnWindow = btn.window else { return }

        // Give SwiftUI room to lay out, then read the height it actually needs.
        // Crucially we must set hosting back to that height BEFORE showing —
        // otherwise SwiftUI centres the VStack in the oversized frame and the
        // visual-effect view clips it to nothing.
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 1000)
        hosting.layoutSubtreeIfNeeded()
        let height = max(hosting.fittingSize.height, 100)
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: height)
        panel.setContentSize(NSSize(width: 280, height: height))

        // Position flush below the status bar button
        let btnScreen = btnWindow.convertToScreen(btn.convert(btn.bounds, to: nil))
        let screenW = NSScreen.main?.frame.width ?? 1440
        let x = min(max(btnScreen.midX - 140, 8), screenW - 288)
        let y = btnScreen.minY - height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)

        // Dismiss when the user clicks anywhere outside the panel
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    func hidePanel() {
        panel?.orderOut(nil)
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    // MARK: - Right-click control menu

    func showControlMenu() {
        let menu = NSMenu()

        let githubItem = NSMenuItem(title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.image = menuIcon("arrow.up.right.square")
        githubItem.target = self
        menu.addItem(githubItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAll), keyEquivalent: "q")
        quitItem.image = menuIcon("power")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func openGitHub() {
        NSWorkspace.shared.open(AppDelegate.githubURL)
    }

    func menuIcon(_ name: String) -> NSImage? {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    // MARK: - Actions

    @objc func quitAll() {
        server.stop()
        NSApp.terminate(nil)
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
withExtendedLifetime(delegate) { app.run() }
