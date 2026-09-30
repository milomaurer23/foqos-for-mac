import SwiftUI

struct ProfileDetailView: View {
    let profile: FocusProfile
    @ObservedObject var store: ProfileStore
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

            HStack {
                Text("Sessions: \(profile.sessionCount)  •  Focused: \(profile.formattedTotalTime)")
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
