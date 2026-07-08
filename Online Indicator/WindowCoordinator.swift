import AppKit
import SwiftUI

/// Manages the lifecycle of the onboarding and settings windows.
/// Conforms to NSWindowDelegate to nil-out the settings window reference on close.
@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {

    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var diagnosticWindow: NSWindow?
    private var diagnosticSession: (any DiagnosticSession)?

    /// Wired by `AppDelegate` to Sparkle’s manual “Check for Updates” action.
    var onCheckForSparkleUpdates: (() -> Void)?

    // MARK: - Onboarding

    func showOnboarding(onStart: @escaping () -> Void) {
        let view = OnboardingView {
            onStart()
        }
        let window = makeWindow(
            size: NSSize(width: 420, height: 480),
            styleMask: [.titled, .closable]
        )
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    // MARK: - Settings

    func openSettings() {
        if let existing = settingsWindow {
            bringSettingsWindowToFront(existing)
            return
        }

        let window = makeWindow(
            size: NSSize(width: 440, height: 740),
            styleMask: [.titled, .closable, .resizable]
        )
        window.title = AppInfo.appName
        let settings = SettingsView(checkForSparkleUpdates: { [weak self] in
            self?.onCheckForSparkleUpdates?()
        })
        window.contentView = NSHostingView(rootView: settings)
        window.delegate = self
        settingsWindow = window
        bringSettingsWindowToFront(window)
    }

    // MARK: - Diagnostics

    func openTraceroute(to host: String) {
        let session = TracerouteSession(host: host)
        openDiagnostic(title: "Traceroute", session: session) {
            TracerouteView(session: session)
        }
    }

    func openDNSLookup(to host: String) {
        let session = DNSLookupSession(host: host)
        openDiagnostic(title: "DNS Lookup", session: session) {
            DNSLookupView(session: session)
        }
    }

    func openPing(to gateway: String?) {
        let session = PingSession(gateway: gateway)
        openDiagnostic(title: "Ping", session: session) {
            PingView(session: session)
        }
    }

    func openTCPPortCheck(host: String, port: Int) {
        let session = TCPConnectSession(host: host, port: port)
        openDiagnostic(title: "TCP Port Check", session: session) {
            TCPConnectView(session: session)
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        }
        if (notification.object as? NSWindow) === diagnosticWindow {
            diagnosticSession?.cancel()
            diagnosticSession = nil
            diagnosticWindow = nil
        }
    }

    // MARK: - Private

    private func openDiagnostic<Session: DiagnosticSession, Content: View>(
        title: String,
        session: Session,
        @ViewBuilder content: () -> Content
    ) {
        diagnosticSession?.cancel()
        diagnosticWindow?.close()

        diagnosticSession = session

        let window = makeWindow(
            size: NSSize(width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable]
        )
        window.title = title
        window.contentView = NSHostingView(rootView: content())
        window.delegate = self
        diagnosticWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(size: NSSize, styleMask: NSWindow.StyleMask) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }

    private func bringSettingsWindowToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .settingsWindowDidBecomeKey, object: nil)
    }
}
