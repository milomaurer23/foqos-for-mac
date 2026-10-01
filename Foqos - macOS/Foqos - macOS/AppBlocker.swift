//
//  AppBlocker.swift
//  Foqos - macOS
//
//  Quits blocked apps while a focus session is running.
//  This is a polite quit (NSRunningApplication.terminate), not a hard lock: it needs no admin
//  rights, and it only works while Foqos itself is open.
//

import AppKit

final class AppBlocker {
    static let shared = AppBlocker()

    /// Apps that can never be blocked, so a profile can't lock the user out of their Mac.
    static let protectedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.systemuiserver"
    ]

    private var blockedBundleIDs: Set<String> = []
    private var launchObserver: NSObjectProtocol?
    private var sweepTimer: Timer?

    private init() {}

    static func isProtected(_ bundleID: String) -> Bool {
        protectedBundleIDs.contains(bundleID) || bundleID == Bundle.main.bundleIdentifier
    }

    var isRunning: Bool { launchObserver != nil }

    /// Starts watching. Apps already open are asked to quit right away.
    func start(bundleIDs: [String]) {
        stop()
        blockedBundleIDs = Set(bundleIDs.filter { !Self.isProtected($0) })
        guard !blockedBundleIDs.isEmpty else { return }

        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.quitIfBlocked(app)
        }

        // Catches apps that were already open, and ones that ignored the first quit request
        // (for example a save dialog the user dismissed).
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.sweep()
        }
        RunLoop.main.add(timer, forMode: .common)
        sweepTimer = timer
        sweep()
    }

    func stop() {
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        launchObserver = nil
        sweepTimer?.invalidate()
        sweepTimer = nil
        blockedBundleIDs = []
    }

    private func sweep() {
        for app in NSWorkspace.shared.runningApplications {
            quitIfBlocked(app)
        }
    }

    private func quitIfBlocked(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier,
              blockedBundleIDs.contains(id),
              !app.isTerminated else { return }
        app.terminate()
    }
}
