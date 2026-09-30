//
//  Models.swift
//  Foqos - macOS
//
//  Data models for the macOS domain blocker
//

import Foundation
import SwiftUI

// MARK: - Blocked Domain

struct BlockedDomain: Identifiable, Codable, Hashable {
    let id: UUID
    var domain: String
    var isEnabled: Bool
    var category: DomainCategory

    init(id: UUID = UUID(), domain: String, isEnabled: Bool = true, category: DomainCategory = .custom) {
        self.id = id
        self.domain = domain
        self.isEnabled = isEnabled
        self.category = category
    }
}

// MARK: - Domain Category

enum DomainCategory: String, Codable, CaseIterable, Identifiable {
    case socialMedia = "Social Media"
    case video = "Video & Streaming"
    case news = "News"
    case shopping = "Shopping"
    case gaming = "Gaming"
    case messaging = "Messaging"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .socialMedia: return "person.2.fill"
        case .video: return "play.rectangle.fill"
        case .news: return "newspaper.fill"
        case .shopping: return "cart.fill"
        case .gaming: return "gamecontroller.fill"
        case .messaging: return "bubble.left.and.bubble.right.fill"
        case .custom: return "globe"
        }
    }

    var color: Color {
        switch self {
        case .socialMedia: return Color(hex: "E91E63")
        case .video: return Color(hex: "F44336")
        case .news: return Color(hex: "2196F3")
        case .shopping: return Color(hex: "FF9800")
        case .gaming: return Color(hex: "9C27B0")
        case .messaging: return Color(hex: "4CAF50")
        case .custom: return Color(hex: "607D8B")
        }
    }

    var presetDomains: [String] {
        switch self {
        case .socialMedia:
            return [
                "facebook.com", "www.facebook.com",
                "twitter.com", "www.twitter.com", "x.com", "www.x.com",
                "instagram.com", "www.instagram.com",
                "tiktok.com", "www.tiktok.com",
                "reddit.com", "www.reddit.com", "old.reddit.com",
                "snapchat.com", "www.snapchat.com",
                "linkedin.com", "www.linkedin.com",
                "threads.net", "www.threads.net",
                "bsky.app",
                "mastodon.social",
                "tumblr.com", "www.tumblr.com",
                "pinterest.com", "www.pinterest.com"
            ]
        case .video:
            return [
                "youtube.com", "www.youtube.com", "m.youtube.com",
                "netflix.com", "www.netflix.com",
                "twitch.tv", "www.twitch.tv",
                "hulu.com", "www.hulu.com",
                "disneyplus.com", "www.disneyplus.com",
                "primevideo.com", "www.primevideo.com",
                "hbomax.com", "www.max.com",
                "crunchyroll.com", "www.crunchyroll.com",
                "vimeo.com", "www.vimeo.com",
                "dailymotion.com", "www.dailymotion.com"
            ]
        case .news:
            return [
                "news.ycombinator.com",
                "cnn.com", "www.cnn.com",
                "bbc.com", "www.bbc.com",
                "nytimes.com", "www.nytimes.com",
                "foxnews.com", "www.foxnews.com",
                "theguardian.com", "www.theguardian.com",
                "washingtonpost.com", "www.washingtonpost.com",
                "buzzfeed.com", "www.buzzfeed.com"
            ]
        case .shopping:
            return [
                "amazon.com", "www.amazon.com",
                "ebay.com", "www.ebay.com",
                "etsy.com", "www.etsy.com",
                "aliexpress.com", "www.aliexpress.com",
                "wish.com", "www.wish.com",
                "target.com", "www.target.com",
                "walmart.com", "www.walmart.com"
            ]
        case .gaming:
            return [
                "store.steampowered.com", "steampowered.com",
                "epicgames.com", "www.epicgames.com",
                "roblox.com", "www.roblox.com",
                "itch.io",
                "kongregate.com", "www.kongregate.com",
                "miniclip.com", "www.miniclip.com",
                "poki.com", "www.poki.com"
            ]
        case .messaging:
            return [
                "discord.com", "www.discord.com",
                "slack.com", "www.slack.com",
                "web.whatsapp.com",
                "web.telegram.org",
                "messenger.com", "www.messenger.com"
            ]
        case .custom:
            return []
        }
    }
}

// MARK: - Focus Profile

struct FocusProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var blockedDomains: [BlockedDomain]
    var isActive: Bool
    var createdAt: Date
    var totalSessionSeconds: Int
    var sessionCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "shield.checkered",
        colorHex: String = "894fa3",
        blockedDomains: [BlockedDomain] = [],
        isActive: Bool = false,
        createdAt: Date = Date(),
        totalSessionSeconds: Int = 0,
        sessionCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.blockedDomains = blockedDomains
        self.isActive = isActive
        self.createdAt = createdAt
        self.totalSessionSeconds = totalSessionSeconds
        self.sessionCount = sessionCount
    }

    var color: Color {
        Color(hex: colorHex)
    }

    var enabledDomainCount: Int {
        blockedDomains.filter { $0.isEnabled }.count
    }

    var formattedTotalTime: String {
        let hours = totalSessionSeconds / 3600
        let minutes = (totalSessionSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Session

struct FocusSession: Identifiable, Codable {
    let id: UUID
    let profileId: UUID
    let profileName: String
    var startTime: Date
    var endTime: Date?
    var blockedDomainCount: Int

    var isActive: Bool {
        endTime == nil
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }
        return String(format: "%dm %02ds", minutes, seconds)
    }
}

// MARK: - App State

enum AppTab: String, CaseIterable {
    case home = "Home"
    case profiles = "Profiles"
    case history = "History"
    case settings = "Settings"
}

// MARK: - Profile Template

struct ProfileTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let colorHex: String
    let categories: [DomainCategory]
    let description: String

    static let templates: [ProfileTemplate] = [
        ProfileTemplate(
            name: "Deep Work",
            icon: "brain.head.profile.fill",
            colorHex: "894fa3",
            categories: [.socialMedia, .video, .news, .messaging],
            description: "Block all social media, video, news, and messaging for maximum focus"
        ),
        ProfileTemplate(
            name: "Study Mode",
            icon: "book.fill",
            colorHex: "2196F3",
            categories: [.socialMedia, .video, .gaming],
            description: "Block entertainment and social media while studying"
        ),
        ProfileTemplate(
            name: "Bedtime",
            icon: "moon.fill",
            colorHex: "5C6BC0",
            categories: [.socialMedia, .video, .news, .gaming, .shopping],
            description: "Block stimulating content to wind down before sleep"
        ),
        ProfileTemplate(
            name: "Social Detox",
            icon: "person.slash.fill",
            colorHex: "E91E63",
            categories: [.socialMedia, .messaging],
            description: "Take a break from all social platforms and messaging"
        ),
        ProfileTemplate(
            name: "No YouTube",
            icon: "play.slash.fill",
            colorHex: "F44336",
            categories: [.video],
            description: "Block YouTube and streaming sites to avoid rabbit holes"
        )
    ]
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Available Profile Icons

let profileIcons: [String] = [
    "shield.checkered", "brain.head.profile.fill", "book.fill", "moon.fill",
    "person.slash.fill", "play.slash.fill", "bolt.shield.fill", "lock.shield.fill",
    "target", "flame.fill", "star.fill", "sparkles",
    "desktopcomputer", "laptopcomputer", "keyboard.fill", "timer",
    "bell.slash.fill", "eye.slash.fill", "hand.raised.fill", "leaf.fill"
]

// MARK: - Available Profile Colors

let profileColors: [(name: String, hex: String)] = [
    ("Grimace Purple", "894fa3"),
    ("Ocean Blue", "2196F3"),
    ("Mint Fresh", "26A69A"),
    ("Lime Zest", "7CB342"),
    ("Sunset Coral", "FF7043"),
    ("Hot Pink", "E91E63"),
    ("Tangerine", "FF9800"),
    ("Lavender Dream", "AB47BC"),
    ("Forest Green", "388E3C"),
    ("Midnight Navy", "283593"),
    ("Cherry Bomb", "C62828"),
    ("Turquoise Wave", "00897B"),
    ("Golden Hour", "F9A825"),
    ("Slate Stone", "546E7A")
]
