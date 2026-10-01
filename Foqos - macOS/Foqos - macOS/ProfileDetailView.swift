import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProfileDetailView: View {
    let profile: FocusProfile
    @ObservedObject var store: ProfileStore
    @State private var appNotice: String?
    @State private var showingAddDomain = false
    @State private var showingDomainPicker = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: profile.icon).font(.title).foregroundStyle(profile.color)
                    .frame(width: 50, height: 50)
                    .background(profile.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading) {
                    Text(profile.name).font(.title2.bold())
                    Text("\(profile.enabledDomainCount) of \(profile.blockedDomains.count) sites enabled")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if profile.isActive {
                    Button("Stop session") { store.stopSession() }
                        .buttonStyle(.borderedProminent).tint(.red)
                } else {
                    Button("Start session") { store.startSession(for: profile.id) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)

            Divider()

            HStack {
                Text("Blocked sites").font(.title3.bold())
                Spacer()
                Menu {
                    Button { showingDomainPicker = true } label: {
                        Label("Choose popular sites", systemImage: "checklist")
                    }
                    Button { showingAddDomain = true } label: {
                        Label("Add custom domain", systemImage: "globe")
                    }
                } label: {
                    Label("Add sites", systemImage: "plus")
                }
            }
            .padding(.horizontal, 28).padding(.top, 22)

            if profile.blockedDomains.isEmpty {
                ContentUnavailableView("No sites added", systemImage: "globe", description: Text("Add a domain or use a preset category."))
            } else {
                List {
                    ForEach(profile.blockedDomains) { domain in
                        DomainRow(
                            domain: domain,
                            isEnabled: binding(for: domain),
                            remove: { remove(domain) }
                        )
                    }
                    .onDelete(perform: deleteDomains)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocked apps").font(.title3.bold())
                    Text("Quit automatically while a session runs, and again if you reopen them. Only works while Foqos is open.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button { chooseApps() } label: {
                        Label("Choose from Applications…", systemImage: "folder")
                    }
                    let running = runningApps
                    if !running.isEmpty {
                        Divider()
                        Section("Currently open") {
                            ForEach(running, id: \.bundleID) { app in
                                Button(app.name) { addApp(name: app.name, bundleID: app.bundleID) }
                            }
                        }
                    }
                } label: {
                    Label("Add apps", systemImage: "plus")
                }
            }
            .padding(.horizontal, 28).padding(.top, 14)

            if let notice = appNotice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                    .padding(.horizontal, 28).padding(.top, 4)
            }

            if profile.blockedApps.isEmpty {
                Text("No apps added. Add Discord, Steam, Slack or anything else that pulls you away.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.horizontal, 28).padding(.vertical, 12)
            } else {
                List {
                    ForEach(profile.blockedApps) { app in
                        AppRow(
                            app: app,
                            isEnabled: appBinding(for: app),
                            remove: { removeApp(app) }
                        )
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 70, maxHeight: 190)
            }

            HStack {
                Text("Sessions:\(profile.sessionCount)  •  Focused: \(profile.formattedTotalTime)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Delete profile", role: .destructive) { showingDeleteConfirmation = true }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingAddDomain) {
            AddDomainSheet(existingDomains: profile.blockedDomains.map(\.domain)) { domain in
                add(domain)
            }
        }
        .sheet(isPresented: $showingDomainPicker) {
            DomainPickerView(profile: profile, store: store)
        }
        .alert("Delete profile?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteProfile(profile)
            }
        } message: {
            Text("This removes the profile and its site list.")
        }
    }

    private func binding(for domain: BlockedDomain) -> Binding<Bool> {
        Binding(
            get: {
                store.profiles.first(where: { $0.id == profile.id })?
                    .blockedDomains.first(where: { $0.id == domain.id })?.isEnabled ?? false
            },
            set: { enabled in
                guard var current = store.profiles.first(where: { $0.id == profile.id }),
                      let index = current.blockedDomains.firstIndex(where: { $0.id == domain.id }) else { return }
                current.blockedDomains[index].isEnabled = enabled
                store.updateProfile(current)
            }
        )
    }

    private func add(_ domain: String) {
        guard var current = store.profiles.first(where: { $0.id == profile.id }) else { return }
        current.blockedDomains.append(BlockedDomain(domain: domain))
        store.updateProfile(current)
    }

    private func remove(_ domain: BlockedDomain) {
        guard var current = store.profiles.first(where: { $0.id == profile.id }) else { return }
        current.blockedDomains.removeAll { $0.id == domain.id }
        store.updateProfile(current)
    }

    // MARK: App blocking

    /// Regular (Dock) apps that are open right now, minus ones that can't be blocked or are already added.
    private var runningApps: [(name: String, bundleID: String)] {
        let existing = Set(profile.blockedApps.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (name: String, bundleID: String)? in
                guard let id = app.bundleIdentifier,
                      !AppBlocker.isProtected(id),
                      !existing.contains(id) else { return nil }
                return (app.localizedName ?? id, id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Block"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { addApp(from: url) }
    }

    private func addApp(from url: URL) {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            appNotice = "\(url.lastPathComponent) isn't a normal app, so it can't be blocked."
            return
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        addApp(name: name, bundleID: bundleID)
    }

    private func addApp(name: String, bundleID: String) {
        guard !AppBlocker.isProtected(bundleID) else {
            appNotice = "\(name) can't be blocked. Foqos and core macOS apps are always allowed."
            return
        }
        guard var current = store.profiles.first(where: { $0.id == profile.id }) else { return }
        guard !current.blockedApps.contains(where: { $0.bundleID == bundleID }) else {
            appNotice = "\(name) is already in this profile."
            return
        }
        appNotice = nil
        current.blockedApps.append(BlockedApp(name: name, bundleID: bundleID))
        store.updateProfile(current)
    }

    private func removeApp(_ app: BlockedApp) {
        guard var current = store.profiles.first(where: { $0.id == profile.id }) else { return }
        current.blockedApps.removeAll { $0.id == app.id }
        store.updateProfile(current)
    }

    private func appBinding(for app: BlockedApp) -> Binding<Bool> {
        Binding(
            get: {
                store.profiles.first(where: { $0.id == profile.id })?
                    .blockedApps.first(where: { $0.id == app.id })?.isEnabled ?? false
            },
            set: { enabled in
                guard var current = store.profiles.first(where: { $0.id == profile.id }),
                      let index = current.blockedApps.firstIndex(where: { $0.id == app.id }) else { return }
                current.blockedApps[index].isEnabled = enabled
                store.updateProfile(current)
            }
        )
    }

    private func deleteDomains(at offsets: IndexSet) {
        guard var current = store.profiles.first(where: { $0.id == profile.id }) else { return }
        current.blockedDomains.remove(atOffsets: offsets)
        store.updateProfile(current)
    }
}

// MARK: - Domain Row

private struct DomainRow: View {
    let domain: BlockedDomain
    @Binding var isEnabled: Bool
    let remove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: domain.category.icon).foregroundStyle(domain.category.color)
            Text(domain.domain)
                .foregroundStyle(isEnabled ? .primary : .secondary)
            Spacer()
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovering ? 1 : 0)
            .help("Remove \(domain.domain)")
            .accessibilityLabel("Remove \(domain.domain)")

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .help(isEnabled ? "Blocked during sessions" : "Ignored during sessions")
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(isEnabled ? "Disable" : "Enable") { isEnabled.toggle() }
            Button("Remove", role: .destructive, action: remove)
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: BlockedApp
    @Binding var isEnabled: Bool
    let remove: () -> Void

    @State private var isHovering = false

    private var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 22, height: 22)
            } else {
                Image(systemName: "app.dashed").frame(width: 22, height: 22).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name).foregroundStyle(isEnabled ? .primary : .secondary)
                Text(app.bundleID).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovering ? 1 : 0)
            .help("Remove \(app.name)")
            .accessibilityLabel("Remove \(app.name)")

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .help(isEnabled ? "Quit during sessions" : "Ignored during sessions")
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(isEnabled ? "Disable" : "Enable") { isEnabled.toggle() }
            Button("Remove", role: .destructive, action: remove)
        }
    }
}

// MARK: - Add Domain Sheet

/// A sheet rather than an alert with a text field: alerts dismiss themselves the moment a
/// button is tapped, which made it impossible to show a validation error without the
/// message silently disappearing.
private struct AddDomainSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existingDomains: [String]
    let onAdd: (String) -> Void

    @State private var text = ""
    @FocusState private var fieldFocused: Bool

    /// `nil` means the current input is good to add.
    private var validationError: String? {
        let value = normalized
        if value.isEmpty { return nil } // don't scold an empty field
        if value.contains("/") || value.contains(":") {
            return "Leave off https:// and any path — just the domain."
        }
        guard HostsManager.isValidDomain(value) else {
            return "That doesn't look like a domain. Try something like youtube.com."
        }
        if existingDomains.contains(value) {
            return "\(value) is already in this profile."
        }
        return nil
    }

    private var normalized: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        !normalized.isEmpty && validationError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a domain").font(.title2.bold())

            TextField("youtube.com", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { submit() }

            Group {
                if let error = validationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("Blocks the domain while a session is running.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 32, alignment: .topLeading)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        guard canSubmit else { return }
        onAdd(normalized)
        dismiss()
    }
}
