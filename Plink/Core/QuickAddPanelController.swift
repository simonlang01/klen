import AppKit
import SwiftUI
import SwiftData
import KeyboardShortcuts

// Borderless windows return false for canBecomeKey by default,
// blocking all keyboard input. This subclass fixes that without
// activating the app or surfacing the main window.
private final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickAddPanelController {
    static let shared = QuickAddPanelController()

    private var panel: NSPanel?
    private var container: ModelContainer?
    private weak var appState: AppState?
    private var mouseMonitor: Any?
    private var isSetUp = false

    private init() {}

    func setup(container: ModelContainer, appState: AppState) {
        guard !isSetUp else { return }
        isSetUp = true
        self.container = container
        self.appState = appState
        KeyboardShortcuts.onKeyUp(for: .quickAdd) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
        NotificationCenter.default.addObserver(forName: .plinkLanguageChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    func toggle() {
        if let panel, panel.isVisible {
            dismiss()
        } else {
            show()
        }
    }

    // MARK: – Show

    private static let autosaveName = "PlinkQuickAddPanel"

    private func show() {
        guard let container else { return }

        let screenWidth = NSScreen.main?.frame.width ?? 1280
        let defaultWidth = screenWidth * 0.5
        let defaultHeight: CGFloat = 98

        let panel = QuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.showsResizeIndicator = true
        panel.minSize = NSSize(width: 360, height: 80)
        panel.maxSize = NSSize(width: min(screenWidth * 0.85, 1200), height: 600)

        let colorScheme = appState?.appearanceMode.colorScheme

        let state = appState ?? AppState()
        let view = QuickAddPanelRoot(onDismiss: { [weak self] in self?.dismiss() })
            .modelContainer(container)
            .environmentObject(state)
            .environment(\.appAccent, state.accentOption.color)
            .environment(\.appFontScale, state.fontScale)
            .environment(\.appFontStyle, state.fontStyle)
            .preferredColorScheme(colorScheme)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)

        // Rounded corners via layer
        host.wantsLayer = true
        host.layer?.cornerRadius = 14
        host.layer?.masksToBounds = true

        panel.contentView = host

        // Restore saved frame or center on screen
        panel.setFrameAutosaveName(Self.autosaveName)
        if !panel.setFrameUsingName(Self.autosaveName) {
            panel.center()
            if let screen = NSScreen.main {
                let frame = panel.frame
                let screenFrame = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: frame.origin.x, y: screenFrame.midY + 80))
            }
        }

        panel.orderFrontRegardless()
        panel.makeKey()

        self.panel = panel

        // Global click-outside monitor
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    // MARK: – Dismiss

    func dismiss() {
        panel?.saveFrame(usingName: Self.autosaveName)
        panel?.orderOut(nil)
        panel = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
}

// Reactive wrapper so font/accent changes in AppState propagate into the panel
private struct QuickAddPanelRoot: View {
    @EnvironmentObject private var appState: AppState
    let onDismiss: () -> Void

    var body: some View {
        QuickAddView(smartInputEnabled: appState.smartInputEnabled, onDismiss: onDismiss)
            .environment(\.appAccent, appState.accentOption.color)
            .environment(\.appFontScale, appState.fontScale)
            .environment(\.appFontStyle, appState.fontStyle)
    }
}
