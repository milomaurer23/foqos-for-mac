import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProfileStore.shared
    @State private var selectedTab: AppTab = .home
    @State private var selectedProfileID: UUID?
    @State private var showingAddProfile = false
    @State private var showingTemplates = false
    @State private var hostsBlockedCount = 0
    @State private var hostsBackupExists = false
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Foqos") {
                    Label("Home", systemImage: "house.fill").tag(AppTab.home)
                    Label("Profiles", systemImage: "square.stack.3d.up.fill").tag(AppTab.profiles)
                    Label("History", systemImage: "clock.fill").tag(AppTab.history)
                    Label("Settings", systemImage: "gear").tag(AppTab.settings)
                }
                Section("Current focus") {
                    if let session = store.activeSession {
                        Label(session.profileName, systemImage: "shield.fill").foregroundStyle(.green)
                        Text(store.formattedElapsedTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    } else {
                        Text("Nothing is blocked").foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Foqos")
            .safeAreaInset(edge: .bottom) {
                Button {
                    selectedTab = .profiles
                    showingAddProfile = true
                } label: {
                    Label("New profile", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        } detail: {
            Group {
                switch selectedTab {
                case .home: homeView
                case .profiles: profilesView
                case .history: historyView
                case .settings: settingsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showingAddProfile) {
            ProfileFormView { profile in
                store.addProfile(profile)
                selectedProfileID = profile.id
                selectedTab = .profiles
            }
        }
        .sheet(isPresented: $showingTemplates) {
            TemplatePickerView { template in
                let profile = store.createFromTemplate(template)
                selectedProfileID = profile.id
                selectedTab = .profiles
            }
        }
        .alert("Could not update blocking", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert("Foqos left blocking active", isPresented: $store.staleBlockDetected) {
            Button("Clear block now") { store.clearStaleBlock() }
            Button("Leave it", role: .cancel) { store.staleBlockDetected = false }
        } message: {
            Text("Foqos found an active block in /etc/hosts but no running session. This usually means the app quit unexpectedly. You can clear the block now or leave it.")
        }
    }

    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.isSessionActive ? "Focus is on" : "Ready to focus?").font(.largeTitle.bold())
                        Text(store.isSessionActive
                             ? "Your selected sites are blocked until you stop the session."
                             : "Choose a profile and block distractions with one click.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: store.isSessionActive ? "shield.fill" : "shield")
                        .font(.system(size: 44))
                        .foregroundStyle(store.isSessionActive ? .green : Color.accentColor)
                }

                if let activeProfile = store.profiles.first(where: { $0.id == store.activeProfileId }) {
                    ActiveSessionCard(profile: activeProfile, elapsed: store.formattedElapsedTime) {
                        store.stopSession()
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Color.accentColor)
                        Text("Blocking changes your Mac only while a session is active. macOS will ask for your password when you start or stop.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                FocusTrackerView(sessions: store.sessions, activeSession: store.activeSession)

                Text("Your profiles").font(.title2.bold())
                if store.profiles.isEmpty {
                    EmptyProfilesView(templateAction: { showingTemplates = true }, customAction: { showingAddProfile = true })
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        ForEach(store.profiles) { profile in
                            ProfileCard(profile: profile, isSelected: profile.id == selectedProfileID) {
                                selectedProfileID = profile.id
                                selectedTab = .profiles
                            } startAction: {
                                store.startSession(for: profile.id)
                            }
                        }

                    }
                }

                FoqosCreditLine()
                    .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .toolbar {
            ToolbarItem {
                Button { showingTemplates = true } label: {
                    Label("Browse templates", systemImage: "sparkles")
                }
            }
        }
    }

    /// Falls back to the first profile when the selection is empty *or* points at a profile
    /// that no longer exists (for example one that was just deleted).
    private var resolvedProfile: FocusProfile? {
        if let id = selectedProfileID,
           let match = store.profiles.first(where: { $0.id == id }) {
            return match
        }
        return store.profiles.first
    }

    private var profilesView: some View {
        HStack(spacing: 0) {
            List(selection: $selectedProfileID) {
                ForEach(store.profiles) { profile in
                    Label {
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text("\(profile.enabledDomainCount) sites").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: profile.icon).foregroundStyle(profile.color)
                    }
                    .tag(profile.id)
                }
            }
            .frame(minWidth: 220, idealWidth: 250)
            .listStyle(.sidebar)

            if let profile = resolvedProfile {
                ProfileDetailView(profile: profile, store: store)
            } else {
                EmptyProfilesView(templateAction: { showingTemplates = true }, customAction: { showingAddProfile = true })
            }
        }
        .toolbar {
            ToolbarItem {
                Button { showingAddProfile = true } label: { Label("New profile", systemImage: "plus") }
            }
            ToolbarItem {
                Button { showingTemplates = true } label: { Label("Templates", systemImage: "sparkles") }
            }
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("History").font(.largeTitle.bold())
            if store.sessions.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "clock", description: Text("Completed focus sessions will appear here."))
            } else {
                List(store.sessions) { session in
                    HStack {
                        Image(systemName: "shield.fill").foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading) {
                            Text(session.profileName).font(.headline)
                            Text(session.startTime, style: .date).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(session.formattedDuration).monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(28)
    }

    private var settingsView: some View {
        Form {
            Section("Credits") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Foqos was created by Ali Waseem.")
                        .font(.headline)
                    Text("Foqos for Mac is a personal Mac version of his free, open-source iPhone app. The idea, the name and the original app are his.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                Link(destination: FoqosCredit.originalRepo) {
                    Label("Ali's original Foqos on GitHub", systemImage: "arrow.up.right.square")
                }
                Link(destination: FoqosCredit.appStore) {
                    Label("Foqos for iPhone on the App Store", systemImage: "arrow.up.right.square")
                }
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
                Text("Foqos adds a clearly marked block to /etc/hosts while a focus session is active.")
                    .foregroundStyle(.secondary)
            }
            Section("Blocking status") {
                LabeledContent("Hosts file") {
                    if hostsBlockedCount > 0 {
                        Label("\(hostsBlockedCount) sites blocked", systemImage: "shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Nothing blocked").foregroundStyle(.secondary)
                    }
                }
                if hostsBlockedCount > 0 {
                    if store.isSessionActive {
                        Text("A session is running. Stop it from Home or the menu bar to unblock.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Foqos found a block in /etc/hosts but no session is running.")
                            .foregroundStyle(.orange)
                        Button("Clear block…", role: .destructive) { showingClearConfirm = true }
                    }
                }
                LabeledContent("Original hosts backup") {
                    Text(hostsBackupExists ? "Saved" : "Not created yet").foregroundStyle(.secondary)
                }
                Button("Refresh") { refreshBlockStatus() }
            }
            Section("Safety") {
                Text("Stopping a session removes only the block created by Foqos. Existing hosts entries are preserved. The first write saves your original hosts file to /etc/hosts.foqos.bak.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(maxWidth: 650, alignment: .leading)
        .onAppear { refreshBlockStatus() }
        .onChange(of: store.isSessionActive) { refreshBlockStatus() }
        .confirmationDialog(
            "Remove Foqos's block from /etc/hosts?",
            isPresented: $showingClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear block", role: .destructive) { clearBlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the Foqos section is removed. You'll be asked for your password.")
        }
    }

    private func refreshBlockStatus() {
        hostsBlockedCount = HostsManager.shared.getCurrentlyBlockedDomains().count
        hostsBackupExists = FileManager.default.fileExists(atPath: "/etc/hosts.foqos.bak")
    }

    private func clearBlock() {
        do {
            try HostsManager.shared.removeBlocking()
            store.staleBlockDetected = false
        } catch {
            store.errorMessage = error.localizedDescription
        }
        refreshBlockStatus()
    }
}

private struct ActiveSessionCard: View {
    let profile: FocusProfile
    let elapsed: String
    let stop: () -> Void

    var body: some View {
        HStack {
            Image(systemName: profile.icon).font(.title2).foregroundStyle(profile.color)
                .frame(width: 42, height: 42)
                .background(profile.color.opacity(0.15), in: Circle())
            VStack(alignment: .leading) {
                Text(profile.name).font(.headline)
                Text("\(profile.enabledDomainCount) sites blocked").foregroundStyle(.secondary)
            }
            Spacer()
            Text(elapsed).font(.title3.monospacedDigit().bold())
            Button("Stop", action: stop).buttonStyle(.borderedProminent).tint(.red)
        }
        .padding(18)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ProfileCard: View {
    let profile: FocusProfile
    let isSelected: Bool
    let select: () -> Void
    let startAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: profile.icon).font(.title2).foregroundStyle(profile.color)
                Spacer()
                if profile.isActive { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            Text(profile.name).font(.headline)
            Text("\(profile.enabledDomainCount) sites ready").font(.callout).foregroundStyle(.secondary)
            Button(profile.isActive ? "Active" : "Start session", action: startAction)
                .buttonStyle(.borderedProminent).disabled(profile.isActive)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(profile.color.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(profile.color.opacity(isSelected ? 0.7 : 0), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
    }
}

private struct EmptyProfilesView: View {
    let templateAction: () -> Void
    let customAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 38)).foregroundStyle(.secondary)
            Text("Create your first profile").font(.title3.bold())
            Text("Start with a preset or choose exactly which domains to block.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack {
                Button("Browse presets", action: templateAction).buttonStyle(.borderedProminent)
                Button("Start from scratch", action: customAction).buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity).padding(40)
    }
}

private struct ProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = profileIcons[0]
    @State private var color = profileColors[0].hex
    let onSave: (FocusProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New profile").font(.title.bold())
            TextField("Profile name", text: $name)
            Picker("Icon", selection: $icon) {
                ForEach(profileIcons, id: \.self) { Image(systemName: $0).tag($0) }
            }
            Picker("Color", selection: $color) {
                ForEach(profileColors, id: \.hex) { item in Text(item.name).tag(item.hex) }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    onSave(FocusProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), icon: icon, colorHex: color))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 360)
    }
}

private struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ProfileTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a preset").font(.title.bold())
            Text("You can edit the sites after creating it.").foregroundStyle(.secondary)
            ScrollView {
                ForEach(ProfileTemplate.templates) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: template.icon).font(.title2)
                                .foregroundStyle(Color(hex: template.colorHex)).frame(width: 34)
                            VStack(alignment: .leading) {
                                Text(template.name).font(.headline)
                                Text(template.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack { Spacer(); Button("Cancel") { dismiss() } }
        }
        .padding(28)
        .frame(width: 500, height: 430)
    }
}

/// Focus history at a glance. Days are shaded by how long you actually focused, not by how
/// many times you pressed start, so a 2-hour session reads as more than four 5-minute ones.
private struct FocusTrackerView: View {
    let sessions: [FocusSession]
    let activeSession: FocusSession?

    private let calendar = Calendar.current
    @State private var displayedMonth = Date()

    /// Completed sessions plus the one currently running, so today's numbers tick up live.
    private var allSessions: [FocusSession] {
        sessions + (activeSession.map { [$0] } ?? [])
    }

    // MARK: Totals
    // Every figure below buckets a session by the day it *started*, so one session is
    // never counted twice or split across two days.

    private func seconds(on date: Date) -> Int {
        allSessions
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .reduce(0) { $0 + Int($1.duration) }
    }

    private func count(for date: Date) -> Int {
        allSessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }.count
    }

    private var last30Days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { calendar.date(byAdding: .day, value: -29 + $0, to: today) }
    }

    private var displayedMonthSeconds: Int {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return 0 }
        return allSessions
            .filter { $0.startTime >= interval.start && $0.startTime < interval.end }
            .reduce(0) { $0 + Int($1.duration) }
    }

    private var totalSeconds: Int {
        allSessions.reduce(0) { $0 + Int($1.duration) }
    }

    /// Consecutive days with focus time, counting back from today. A day that hasn't
    /// started yet shouldn't break the streak, so an empty today falls back to yesterday.
    private var currentStreak: Int {
        var day = calendar.startOfDay(for: Date())
        if seconds(on: day) == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while seconds(on: day) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let days = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let leading = calendar.component(.weekday, from: interval.start) - calendar.firstWeekday
        let emptyCount = (leading + 7) % 7
        let emptyCells = Array(repeating: Date?.none, count: emptyCount)
        let dates = days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return emptyCells + dates.map(Optional.some)
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your focus").font(.title2.bold())
                Spacer()
                Text("\(allSessions.count) total session\(allSessions.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                TrackerMetric(
                    title: "Today",
                    value: FocusLevel.short(seconds(on: today)),
                    detail: activeSession == nil ? "focused" : "and counting",
                    tint: FocusLevel.of(seconds: seconds(on: today)).color
                )
                TrackerMetric(
                    title: displayedMonth.formatted(.dateTime.month(.wide)),
                    value: FocusLevel.short(displayedMonthSeconds),
                    detail: "this month",
                    tint: .accentColor
                )
                TrackerMetric(
                    title: "Streak",
                    value: "\(currentStreak)",
                    detail: currentStreak == 1 ? "day in a row" : "days in a row",
                    tint: currentStreak > 0 ? FocusLevel.strong.color : .secondary
                )
                TrackerMetric(
                    title: "All time",
                    value: FocusLevel.short(totalSeconds),
                    detail: "\(last30Days.filter { count(for: $0) > 0 }.count) active days in 30",
                    tint: .accentColor
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(displayedMonth, format: .dateTime.month(.wide).year()).font(.headline)
                    Spacer()
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .help("Previous month")
                    Button("Today") { displayedMonth = Date() }
                        .disabled(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month))
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .help("Next month")
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(calendar.shortWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                        Text(day.prefix(1)).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                        if let date {
                            DayCell(
                                day: calendar.component(.day, from: date),
                                seconds: seconds(on: date),
                                sessionCount: count(for: date),
                                isToday: calendar.isDateInToday(date),
                                isFuture: date > today
                            )
                        } else {
                            Color.clear.frame(height: 32)
                        }
                    }
                }

                FocusLegend()
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }

    private func shiftMonth(_ delta: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }
}

// MARK: - Focus Intensity

/// How much focus a single day represents. Everything colour-coded in the tracker runs
/// through this so the shades always mean the same thing.
private enum FocusLevel: Int, CaseIterable {
    case none, light, moderate, strong, deep

    static func of(seconds: Int) -> FocusLevel {
        switch seconds / 60 {
        case 0: return .none
        case ..<30: return .light
        case ..<60: return .moderate
        case ..<120: return .strong
        default: return .deep
        }
    }

    var color: Color {
        switch self {
        case .none: return Color.secondary.opacity(0.16)
        case .light: return Color(hex: "A5D6A7")
        case .moderate: return Color(hex: "66BB6A")
        case .strong: return Color(hex: "43A047")
        case .deep: return Color(hex: "2E7D32")
        }
    }

    /// Dark shades need light text; the two palest ones don't.
    var textColor: Color {
        switch self {
        case .none: return .primary
        case .light: return Color(hex: "1B5E20")
        case .moderate, .strong, .deep: return .white
        }
    }

    var label: String {
        switch self {
        case .none: return "No focus"
        case .light: return "Under 30 min"
        case .moderate: return "30 min – 1 hr"
        case .strong: return "1 – 2 hrs"
        case .deep: return "2 hrs or more"
        }
    }

    static func short(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return seconds > 0 ? "<1m" : "0m"
    }
}

private struct DayCell: View {
    let day: Int
    let seconds: Int
    let sessionCount: Int
    let isToday: Bool
    let isFuture: Bool

    private var level: FocusLevel { FocusLevel.of(seconds: seconds) }

    private var tooltip: String {
        guard sessionCount > 0 else { return "No focus time" }
        return "\(FocusLevel.short(seconds)) across \(sessionCount) session\(sessionCount == 1 ? "" : "s")"
    }

    var body: some View {
        Text("\(day)")
            .font(.callout.weight(level == .none ? .regular : .semibold))
            .foregroundStyle(isFuture ? Color.secondary.opacity(0.4) : level.textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(isFuture ? Color.clear : level.color, in: Circle())
            .overlay {
                if isToday {
                    Circle().stroke(Color.accentColor, lineWidth: 2)
                }
            }
            .help(tooltip)
            .accessibilityLabel("Day \(day), \(tooltip)")
    }
}

private struct FocusLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach(FocusLevel.allCases, id: \.rawValue) { level in
                Circle()
                    .fill(level.color)
                    .frame(width: 11, height: 11)
                    .help(level.label)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text("Shaded by time focused each day")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

private struct TrackerMetric: View {
    let title: String
    let value: String
    let detail: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(tint)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(detail).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Credit

/// Foqos is Ali Waseem's app. This Mac version credits him wherever it introduces itself.
enum FoqosCredit {
    static let originalRepo = URL(string: "https://github.com/awaseem/foqos")!
    static let appStore = URL(string: "https://apps.apple.com/ca/app/foqos/id6736793117")!
}

private struct FoqosCreditLine: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Based on Foqos by Ali Waseem.")
            Link("View the original on GitHub", destination: FoqosCredit.originalRepo)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
