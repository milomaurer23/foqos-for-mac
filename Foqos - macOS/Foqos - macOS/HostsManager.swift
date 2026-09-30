//
//  HostsManager.swift
//  Foqos - macOS
//
//  Manages /etc/hosts modifications for domain blocking.
//  Uses osascript with administrator privileges to write to /etc/hosts.
//

import Foundation

class HostsManager {
    static let shared = HostsManager()

    private let hostsPath = "/etc/hosts"
    private let beginMarker = "# >>> FOQOS BLOCK START <<<"
    private let endMarker = "# >>> FOQOS BLOCK END <<<"
    private let backupPath = "/etc/hosts.foqos.bak"

    private init() {}

    // MARK: - Public API

    /// Apply blocking for the given domains by adding entries to /etc/hosts
    func applyBlocking(domains: [String]) throws {
        let currentContent = try readHostsFile()
        let cleanedContent = removeExistingFoqosBlock(from: currentContent)

        guard !domains.isEmpty else {
            // If no domains, just clean up any existing block
            try writeHostsFile(content: cleanedContent)
            flushDNSCache()
            return
        }

        let blockEntries = buildBlockEntries(for: domains)
        let newContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            + "\n\n"
            + beginMarker + "\n"
            + blockEntries
            + endMarker + "\n"

        try writeHostsFile(content: newContent)
        flushDNSCache()
    }

    /// Remove all Foqos blocks from /etc/hosts
    func removeBlocking() throws {
        let currentContent = try readHostsFile()
        let cleanedContent = removeExistingFoqosBlock(from: currentContent)
        try writeHostsFile(content: cleanedContent)
        flushDNSCache()
    }

    /// Check if Foqos blocking is currently active in /etc/hosts
    func isBlockingActive() -> Bool {
        guard let content = try? readHostsFile() else { return false }
        return content.contains(beginMarker)
    }

    /// ASCII hostnames only (letters, digits, hyphens) with no empty labels.
    /// Also the guard that keeps stray characters out of /etc/hosts.
    static func isValidDomain(_ domain: String) -> Bool {
        guard domain.count <= 253 else { return false }
        let parts = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty &&
            part.count <= 63 &&
            part.first != "-" &&
            part.last != "-" &&
            part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }

    /// Get currently blocked domains from /etc/hosts
    func getCurrentlyBlockedDomains() -> [String] {
        guard let content = try? readHostsFile() else { return [] }

        guard let blockRange = nextBlockRange(in: content) else { return [] }

        let blockSection = String(content[blockRange])
        return blockSection
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("0.0.0.0 "),
                      !trimmed.hasPrefix("#") else { return nil }
                return String(trimmed.dropFirst("0.0.0.0 ".count))
            }
    }

    // MARK: - Private Helpers

    private func readHostsFile() throws -> String {
        return try String(contentsOfFile: hostsPath, encoding: .utf8)
    }

    private func writeHostsFile(content: String) throws {
        // Single osascript call writes the hosts file AND flushes DNS cache,
        // so the user only sees ONE password dialog per start/stop.
        let tempPath = NSTemporaryDirectory() + "foqos_hosts_\(UUID().uuidString)"
        try content.write(toFile: tempPath, atomically: true, encoding: .utf8)

        // The whole write is one && chain, so the exit status reflects a failed copy.
        // Only the cache flush is allowed to fail quietly (it ends in `true`).
        // The one-time backup keeps the user's original hosts file recoverable.
        let escapedPath = tempPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        set tempFile to "\(escapedPath)"
        do shell script "( [ -f \(backupPath) ] || cp \(hostsPath) \(backupPath) ) && cp " & quoted form of tempFile & " \(hostsPath) && chmod 644 \(hostsPath) && { dscacheutil -flushcache; killall -HUP mDNSResponder; true; }" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // Clean up temp file in case the script failed before removing it
        try? FileManager.default.removeItem(atPath: tempPath)

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            if errorString.contains("User canceled") || errorString.contains("-128") {
                throw HostsManagerError.userCancelled
            }
            throw HostsManagerError.writeFailed(errorString)
        }

        // Confirm the write landed instead of trusting the exit status alone.
        guard let written = try? readHostsFile(), written == content else {
            throw HostsManagerError.writeFailed("/etc/hosts does not match what Foqos wrote.")
        }
    }

    private func removeExistingFoqosBlock(from content: String) -> String {
        var result = content
        // Loop so a duplicated block (from an earlier bug or a manual edit) is fully cleared.
        while let blockRange = nextBlockRange(in: result) {
            result.removeSubrange(blockRange)
        }

        // Clean up extra blank lines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result
    }

    /// Range of the first Foqos block, whole lines from the start marker through the end marker.
    /// The end marker must come after the start marker. If it's missing (a half-written block),
    /// the range covers the start marker and the Foqos-generated lines right after it, and stops
    /// at the first line that isn't ours.
    private func nextBlockRange(in content: String) -> Range<String.Index>? {
        guard let startRange = content.range(of: beginMarker) else { return nil }
        let lineStart = content.lineRange(for: startRange).lowerBound

        if let endRange = content.range(of: endMarker, range: startRange.upperBound..<content.endIndex) {
            return lineStart..<content.lineRange(for: endRange).upperBound
        }

        var end = content.lineRange(for: startRange).upperBound
        while end < content.endIndex {
            let lineRange = content.lineRange(for: end..<end)
            let line = content[lineRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let isFoqosLine = line.isEmpty
                || line.hasPrefix("0.0.0.0 ")
                || line.hasPrefix("# Blocked by Foqos")
                || line.hasPrefix("# Active since:")
            guard isFoqosLine else { break }
            end = lineRange.upperBound
        }
        return lineStart..<end
    }

    private func buildBlockEntries(for domains: [String]) -> String {
        var entries = "# Blocked by Foqos — do not edit manually\n"
        entries += "# Active since: \(ISO8601DateFormatter().string(from: Date()))\n"

        // Never write a line that could inject extra hosts entries.
        for domain in domains where Self.isValidDomain(domain) {
            entries += "0.0.0.0 \(domain)\n"
        }

        return entries
    }

    private func flushDNSCache() {
        // No-op: DNS flush is bundled into writeHostsFile to avoid a second password dialog.
    }
}

// MARK: - Errors

enum HostsManagerError: LocalizedError {
    case userCancelled
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Password entry was cancelled. Blocking was not applied."
        case .writeFailed(let detail):
            return "Failed to modify /etc/hosts: \(detail)"
        }
    }
}
