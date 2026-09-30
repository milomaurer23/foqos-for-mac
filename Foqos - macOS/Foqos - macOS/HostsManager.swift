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

    static func isValidDomain(_ domain: String) -> Bool {
        let parts = domain.split(separator: ".", omittingEmptySubsequences: true)
        guard parts.count >= 2, domain.count <= 253 else { return false }
        return parts.allSatisfy { part in
            part.count <= 63 &&
            part.first != "-" &&
            part.last != "-" &&
            part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }

    /// Get currently blocked domains from /etc/hosts
    func getCurrentlyBlockedDomains() -> [String] {
        guard let content = try? readHostsFile() else { return [] }

        guard let startRange = content.range(of: beginMarker),
              let endRange = content.range(of: endMarker) else {
            return []
        }

        let blockSection = String(content[startRange.upperBound..<endRange.lowerBound])
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

        let script = """
        do shell script "cp \(tempPath) /etc/hosts && chmod 644 /etc/hosts && rm -f \(tempPath) && dscacheutil -flushcache; killall -HUP mDNSResponder" with administrator privileges
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
    }

    private func removeExistingFoqosBlock(from content: String) -> String {
        guard let startRange = content.range(of: beginMarker),
              let endRange = content.range(of: endMarker) else {
            return content
        }

        // Find the start of the line containing beginMarker
        var blockStart = startRange.lowerBound
        while blockStart > content.startIndex {
            let prevIndex = content.index(before: blockStart)
            if content[prevIndex] == "\n" {
                break
            }
            blockStart = prevIndex
        }

        let blockEnd = endRange.upperBound
        var result = String(content[content.startIndex..<blockStart])
        if blockEnd < content.endIndex {
            result += String(content[blockEnd...])
        }

        // Clean up extra blank lines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result
    }

    private func buildBlockEntries(for domains: [String]) -> String {
        var entries = "# Blocked by Foqos — do not edit manually\n"
        entries += "# Active since: \(ISO8601DateFormatter().string(from: Date()))\n"

        for domain in domains {
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
