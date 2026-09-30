//
//  Foqos___macOSApp.swift
//  Foqos - macOS
//

import SwiftUI

@main
struct Foqos_macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ProfileStore.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }

        // Outline shield when idle, filled shield while a session is blocking.
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: store.isSessionActive ? "shield.fill" : "shield")
                .accessibilityLabel(store.isSessionActive ? "Foqos: blocking" : "Foqos: idle")
        }
    }
}

/// Catches quit so a running session can never silently leave a block behind in /etc/hosts.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let store = ProfileStore.shared
        guard let session = store.activeSession else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "\"\(session.profileName)\" is still blocking"
        alert.informativeText = """
            Your blocked sites will stay blocked unless you stop the session first.

            If you keep blocking, Foqos picks the session back up the next time you open it.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Stop Blocking and Quit")
        alert.addButton(withTitle: "Keep Blocking and Quit")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            store.stopSession()
            // stopSession leaves the session running if the block couldn't be lifted
            // (for example the password prompt was dismissed) — don't quit in that case.
            return store.isSessionActive ? .terminateCancel : .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}

private struct MenuBarView: View {
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let session = store.activeSession {
            Text("\(session.profileName) · \(store.formattedElapsedTime)")
            Button("Stop blocking") {
                store.stopSession()
            }
        } else {
            Text("Ready to focus")
            if store.profiles.isEmpty {
                Text("Create a profile in the dashboard")
            } else {
                ForEach(store.profiles) { profile in
                    Button("Start \(profile.name)") {
                        store.startSession(for: profile.id)
                    }
                }
            }
        }

        Divider()

        Button("Open dashboard") {
            openWindow(id: "main")
        }
        Button("Quit Foqos") {
            NSApplication.shared.terminate(nil)
        }
    }
}
