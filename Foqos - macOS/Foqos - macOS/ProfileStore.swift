//
//  ProfileStore.swift
//  Foqos - macOS
//
//  Persistence layer for profiles and sessions using JSON files in Application Support.
//

import Foundation
import Combine
import SwiftUI

class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var profiles: [FocusProfile] = []
    @Published var sessions: [FocusSession] = []
    @Published var activeSession: FocusSession?
    @Published var activeProfileId: UUID?
    @Published var sessionTimer: Timer?
    @Published var elapsedSeconds: Int = 0
    @Published var errorMessage: String?
    @Published var staleBlockDetected: Bool = false

    private let fileManager = FileManager.default

    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let foqosDir = appSupport.appendingPathComponent("Foqos-macOS", isDirectory: true)
        try? fileManager.createDirectory(at: foqosDir, withIntermediateDirectories: true)
        return foqosDir
    }

    private var profilesURL: URL { storageURL.appendingPathComponent("profiles.json") }
    private var sessionsURL: URL { storageURL.appendingPathComponent("sessions.json") }
    private var activeSessionURL: URL { storageURL.appendingPathComponent("active-session.json") }

    private init() {
        loadProfiles()
        loadSessions()
        restoreActiveSession()
    }

    /// Reconciles what's on disk with what's in /etc/hosts. The two can disagree if the app
    /// quit while blocking, or if someone edited the hosts file by hand.
    private func restoreActiveSession() {
        let blockIsActive = HostsManager.shared.isBlockingActive()
        let savedSession = loadActiveSession()

        switch (blockIsActive, savedSession) {
        case (true, .some(let session)):
            // Block and session agree — pick the session back up where it left off.
            activeSession = session
            activeProfileId = session.profileId
            markProfileActive(session.profileId)
            startTimer()

        case (true, .none):
            // A block is live but we have no record of it. Let the user clear it.
            markProfileActive(nil)
            staleBlockDetected = true

        case (false, .some(let session)):
            // The block is gone but the session was never closed out. Archive it so the
            // time isn't lost, then start clean.
            var finished = session
            finished.endTime = Date()
            archive(finished)
            clearActiveSessionFile()
            markProfileActive(nil)

        case (false, .none):
            markProfileActive(nil)
        }
    }

    func clearStaleBlock() {
        do {
            try HostsManager.shared.removeBlocking()
        } catch {
            errorMessage = error.localizedDescription
        }
        staleBlockDetected = false
    }

    // MARK: - Profile CRUD

    func addProfile(_ profile: FocusProfile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: FocusProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }

    func deleteProfile(_ profile: FocusProfile) {
        // Stop if this profile is active
        if activeProfileId == profile.id {
            stopSession()
        }
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
    }

    func createFromTemplate(_ template: ProfileTemplate) -> FocusProfile {
        var domains: [BlockedDomain] = []
        for category in template.categories {
            for domain in category.presetDomains {
                domains.append(BlockedDomain(domain: domain, category: category))
            }
        }

        let profile = FocusProfile(
            name: template.name,
            icon: template.icon,
            colorHex: template.colorHex,
            blockedDomains: domains
        )
        addProfile(profile)
        return profile
    }

    // MARK: - Session Management

    func startSession(for profileId: UUID) {
        guard activeSession == nil else { return } // ignore if a session is already running
        guard let profile = profiles.first(where: { $0.id == profileId }) else { return }

        let enabledDomains = profile.blockedDomains.filter { $0.isEnabled }.map { $0.domain }

        do {
            try HostsManager.shared.applyBlocking(domains: enabledDomains)
        } catch HostsManagerError.userCancelled {
            errorMessage = HostsManagerError.userCancelled.localizedDescription
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let session = FocusSession(
            id: UUID(),
            profileId: profileId,
            profileName: profile.name,
            startTime: Date(),
            blockedDomainCount: enabledDomains.count
        )

        activeSession = session
        activeProfileId = profileId
        saveActiveSession(session)

        // Mark profile as active
        if let index = profiles.firstIndex(where: { $0.id == profileId }) {
            profiles[index].isActive = true
            profiles[index].sessionCount += 1
            saveProfiles()
        }

        startTimer()
    }

    /// Ends the running session. If the block can't be lifted (for example the user dismisses
    /// the password prompt) the session stays running so the app never claims to have
    /// unblocked something it didn't.
    func stopSession() {
        guard let session = activeSession else {
            stopTimer()
            markProfileActive(nil)
            return
        }

        do {
            try HostsManager.shared.removeBlocking()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        stopTimer()

        var finished = session
        finished.endTime = Date()
        archive(finished)
        clearActiveSessionFile()

        if let index = profiles.firstIndex(where: { $0.id == finished.profileId }) {
            profiles[index].totalSessionSeconds += Int(finished.duration)
            saveProfiles()
        }

        activeSession = nil
        markProfileActive(nil)
        elapsedSeconds = 0
    }

    var isSessionActive: Bool {
        activeSession != nil
    }

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Timer

    /// The elapsed time is always derived from the session's start date rather than counted
    /// up tick by tick, so it stays correct across sleep, app relaunch, and dropped timers.
    private func startTimer() {
        stopTimer()
        refreshElapsed()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshElapsed()
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionTimer = timer
    }

    private func stopTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func refreshElapsed() {
        guard let session = activeSession else { return }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(session.startTime)))
    }

    // MARK: - Active State Helpers

    /// Single place that keeps `profiles[].isActive` in step with `activeProfileId`.
    private func markProfileActive(_ id: UUID?) {
        activeProfileId = id
        var changed = false
        for index in profiles.indices {
            let shouldBeActive = profiles[index].id == id
            if profiles[index].isActive != shouldBeActive {
                profiles[index].isActive = shouldBeActive
                changed = true
            }
        }
        if changed { saveProfiles() }
    }

    private func archive(_ session: FocusSession) {
        sessions.insert(session, at: 0)
        saveSessions()
    }

    // MARK: - Persistence

    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: profilesURL)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }

    private func loadProfiles() {
        guard let data = try? Data(contentsOf: profilesURL),
              let loaded = try? JSONDecoder().decode([FocusProfile].self, from: data) else {
            return
        }
        profiles = loaded
    }

    private func saveSessions() {
        do {
            // Keep last 100 sessions
            let toSave = Array(sessions.prefix(100))
            let data = try JSONEncoder().encode(toSave)
            try data.write(to: sessionsURL)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }

    private func loadSessions() {
        guard let data = try? Data(contentsOf: sessionsURL),
              let loaded = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return
        }
        sessions = loaded
    }

    private func saveActiveSession(_ session: FocusSession) {
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: activeSessionURL)
        } catch {
            print("Failed to save active session: \(error)")
        }
    }

    private func loadActiveSession() -> FocusSession? {
        guard let data = try? Data(contentsOf: activeSessionURL),
              let session = try? JSONDecoder().decode(FocusSession.self, from: data) else {
            return nil
        }
        return session
    }

    private func clearActiveSessionFile() {
        try? fileManager.removeItem(at: activeSessionURL)
    }
}
