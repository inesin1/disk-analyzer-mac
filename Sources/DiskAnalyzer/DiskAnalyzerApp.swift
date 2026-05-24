import AppKit
import SwiftUI

@main
struct DiskAnalyzerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Disk Analyzer") {
            ContentView()
        }
    }
}

/// Launched by `swift run` there is no app bundle, so the process starts as a background
/// accessory: no dock icon and no key window. Both need to be asked for explicitly.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
