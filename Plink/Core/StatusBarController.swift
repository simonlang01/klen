import AppKit
import SwiftUI
import SwiftData

@MainActor
final class StatusBarController {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var container: ModelContainer?
    private weak var appState: AppState?
    private var popover: NSPopover?
    private(set) var isRunning: Bool = true {
        didSet { updateIcon() }
    }

    private init() {}

    func setup(container: ModelContainer, appState: AppState) {
        self.container = container
        self.appState = appState

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.action = #selector(handleClick)
        item.button?.target = self
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = item

        updateIcon()
    }

    // MARK: – Icon

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusImage(running: isRunning)
    }

    private func makeStatusImage(running: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let symbol = NSImage(systemSymbolName: "checklist", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            symbol?.draw(in: NSRect(x: 1, y: 2, width: 13, height: 13))

            let dotRadius: CGFloat = 3.5
            let dotCenter = NSPoint(x: rect.maxX - dotRadius - 0.5, y: rect.minY + dotRadius + 0.5)
            let dotRect = NSRect(
                x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            )
            (running ? NSColor.systemGreen : NSColor.systemRed).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: – Click

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: – Popover

    private func togglePopover() {
        if let pop = popover, pop.isShown {
            pop.performClose(nil)
            return
        }
        guard let button = statusItem?.button, let container else { return }

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true

        let accentColor = appState?.accentOption.color ?? Theme.defaultAccent
        let colorScheme = appState?.appearanceMode.colorScheme
        let content = MenuBarPopoverView { [weak self] in
            pop.performClose(nil)
            self?.openMainWindow()
        }
        .modelContainer(container)
        .environment(\.appAccent, accentColor)
        .preferredColorScheme(colorScheme)

        pop.contentViewController = NSHostingController(rootView: content)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        pop.contentViewController?.view.window?.makeKey()

        self.popover = pop
    }

    // MARK: – Context menu (right-click)

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Plink", action: #selector(openApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quickAddItem = NSMenuItem(title: "New Task", action: #selector(triggerQuickAdd), keyEquivalent: "")
        quickAddItem.target = self
        menu.addItem(quickAddItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Plink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: – Actions

    @objc private func openApp() {
        openMainWindow()
    }

    @objc private func triggerQuickAdd() {
        QuickAddPanelController.shared.toggle()
    }

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) ?? NSApp.windows.first(where: { !($0 is NSPanel) }) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: – State

    func setError(_ hasError: Bool) {
        isRunning = !hasError
    }
}
