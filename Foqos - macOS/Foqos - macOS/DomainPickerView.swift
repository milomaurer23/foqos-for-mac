import SwiftUI

private struct PopularDomain: Identifiable {
    let id: String
    let name: String
    let domains: [String]
    let category: DomainCategory
}

private let popularDomains = [
    PopularDomain(id: "youtube", name: "YouTube", domains: ["youtube.com", "www.youtube.com", "m.youtube.com"], category: .video),
    PopularDomain(id: "netflix", name: "Netflix", domains: ["netflix.com", "www.netflix.com"], category: .video),
    PopularDomain(id: "twitch", name: "Twitch", domains: ["twitch.tv", "www.twitch.tv"], category: .video),
    PopularDomain(id: "facebook", name: "Facebook", domains: ["facebook.com", "www.facebook.com"], category: .socialMedia),
    PopularDomain(id: "instagram", name: "Instagram", domains: ["instagram.com", "www.instagram.com"], category: .socialMedia),
    PopularDomain(id: "tiktok", name: "TikTok", domains: ["tiktok.com", "www.tiktok.com"], category: .socialMedia),
    PopularDomain(id: "x", name: "X / Twitter", domains: ["x.com", "www.x.com", "twitter.com", "www.twitter.com"], category: .socialMedia),
    PopularDomain(id: "reddit", name: "Reddit", domains: ["reddit.com", "www.reddit.com", "old.reddit.com"], category: .socialMedia),
    PopularDomain(id: "discord", name: "Discord", domains: ["discord.com", "www.discord.com"], category: .messaging),
    PopularDomain(id: "amazon", name: "Amazon", domains: ["amazon.com", "www.amazon.com"], category: .shopping),
    PopularDomain(id: "steam", name: "Steam", domains: ["store.steampowered.com", "steampowered.com"], category: .gaming),
    PopularDomain(id: "news", name: "News sites", domains: ["cnn.com", "bbc.com", "nytimes.com"], category: .news)
]

struct DomainPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: FocusProfile
    @ObservedObject var store: ProfileStore
    @State private var selected = Set<String>()

    private var groupedDomains: [(DomainCategory, [PopularDomain])] {
        DomainCategory.allCases.compactMap { category in
            let items = popularDomains.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose sites to block").font(.title.bold())
            Text("Select the services you want included in this profile.")
                .foregroundStyle(.secondary)
            List {
                ForEach(groupedDomains, id: \.0) { category, items in
                    Section {
                        ForEach(items) { item in
                            Button {
                                if selected.contains(item.id) {
                                    selected.remove(item.id)
                                } else {
                                    selected.insert(item.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: item.category.icon).foregroundStyle(item.category.color)
                                    Text(item.name)
                                    Spacer()
                                    Image(systemName: selected.contains(item.id) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selected.contains(item.id) ? Color.accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add selected") { addSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 430, height: 520)
        .onAppear {
            selected = Set(popularDomains.filter { item in
                item.domains.allSatisfy { domain in profile.blockedDomains.contains(where: { $0.domain == domain }) }
            }.map(\.id))
        }
    }

    private func addSelected() {
        guard var current = store.profiles.first(where: { $0.id == profile.id }) else { return }
        for item in popularDomains where selected.contains(item.id) {
            for domain in item.domains where !current.blockedDomains.contains(where: { $0.domain == domain }) {
                current.blockedDomains.append(BlockedDomain(domain: domain, category: item.category))
            }
        }
        store.updateProfile(current)
        dismiss()
    }
}
