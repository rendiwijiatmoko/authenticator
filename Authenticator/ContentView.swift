//
//  ContentView.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AccountStore()
    @State private var search = ""
    @State private var showScanner = false
    @State private var showSettings = false
    @State private var sortByName = false
    @State private var copiedID: UUID?
    @State private var copiedResetTask: Task<Void, Never>?
    @State private var pendingDeletion: TOTPAccount?
    @State private var editingAccount: TOTPAccount?
    @State private var importedAccount: TOTPAccount?
    @State private var pendingImportedAccount: TOTPAccount?
    @AppStorage("showNextCode") private var showNextCode = true
    @State private var searchPresented = false

    private var filteredAccounts: [TOTPAccount] {
        let accounts = store.accounts.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.issuer.localizedCaseInsensitiveContains(search)
        }
        return sortByName ? accounts.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } : accounts
    }

    private var mainView: some View {
        NavigationStack {
            ZStack {
                AuthenticatorTheme.background(for: colorScheme).ignoresSafeArea()
                VStack(spacing: 24) {
                    if !store.isAvailable {
                        unavailableState
                    } else if store.accounts.isEmpty {
                        emptyState
                    } else if filteredAccounts.isEmpty {
                        ContentUnavailableView.search(text: search)
                            .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredAccounts) { account in
                                accountRow(account)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
                .padding(.top, 14)
            }
            .navigationTitle("Aster Auth")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $search, isPresented: $searchPresented, prompt: "Search")
            .toolbar { mainToolbar }
        }
    }

    var body: some View {
        mainView
        .tint(AuthenticatorTheme.primary)
        .fullScreenCover(isPresented: $showScanner, onDismiss: presentPendingImport) { AddAccountView(store: store) }
        .sheet(isPresented: $showSettings, onDismiss: presentPendingImport) { settings }
        .sheet(item: $editingAccount, onDismiss: presentPendingImport) { account in
            ManualEntryView(account: account, isEditing: true) { updated in
                try store.update(updated)
                editingAccount = nil
            }
        }
        .sheet(item: $importedAccount, onDismiss: presentPendingImport) { account in
            ManualEntryView(account: account) { confirmed in
                try store.add(confirmed)
                importedAccount = nil
            }
        }
        .onOpenURL(perform: receiveSetupURL)
        .alert("Local vault", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog("Delete this account?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                if let account = pendingDeletion { store.delete(account) }
                pendingDeletion = nil
            }
        } message: {
            Text("Make sure you have another way to sign in to \(pendingDeletion?.title ?? "this account").")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
    }

    private func receiveSetupURL(_ url: URL) {
        do {
            let account = try TOTPAccount.parse(uri: url.absoluteString)
            store.reload()
            guard store.isAvailable else { return }
            pendingImportedAccount = account
            // Let any active sheet dismiss before showing the setup form.
            if showScanner { showScanner = false }
            else if showSettings { showSettings = false }
            else if editingAccount != nil { editingAccount = nil }
            else if importedAccount != nil { importedAccount = nil }
            else { presentPendingImport() }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func presentPendingImport() {
        guard !showScanner, !showSettings, editingAccount == nil, importedAccount == nil,
              let account = pendingImportedAccount else { return }
        pendingImportedAccount = nil
        importedAccount = account
    }

    private func accountRow(_ account: TOTPAccount) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            AccountCard(account: account, date: context.date,
                        showNextCode: showNextCode, copied: copiedID == account.id) {
                copy(account)
            }
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 24))
            .contextMenu { accountActions(account) }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Edit", systemImage: "pencil") { editingAccount = account }
                .tint(AuthenticatorTheme.primary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) { pendingDeletion = account }
                .tint(.red)
        }
    }

    @ViewBuilder
    private func accountActions(_ account: TOTPAccount) -> some View {
        Section {
            Button("Copy current code", systemImage: "square.on.square") { copy(account) }
            Button("Copy next code", systemImage: "square.on.square.dashed") { copy(account, offset: 1) }
        }
        Section {
            Button("Edit", systemImage: "pencil") { editingAccount = account }
        }
        Section {
            Button("Delete", systemImage: "trash", role: .destructive) { pendingDeletion = account }
        }
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "ellipsis") { showSettings = true }
        }
        ToolbarItem(placement: .bottomBar) {
            Menu {
                Picker("Sort accounts", selection: $sortByName) {
                    Text("Date added").tag(false)
                    Text("Name").tag(true)
                }
            } label: {
                Label("Sort accounts", systemImage: "line.3.horizontal.decrease")
            }
        }
        ToolbarSpacer(.fixed, placement: .bottomBar)
        DefaultToolbarItem(kind: .search, placement: .bottomBar)
        ToolbarSpacer(.fixed, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button("Add account", systemImage: "plus") {
                searchPresented = false
                showScanner = true
            }
            .disabled(!store.isAvailable)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AuthenticatorTheme.gradient)
                .frame(width: 100, height: 100)
                .background(AuthenticatorTheme.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 30))
            VStack(spacing: 10) {
                Text("Your codes, always with you")
                    .font(.title3.weight(.semibold))
                Text("Add your first account to get started.\nYour codes work even when you're offline.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Button { showScanner = true } label: {
                Label("Add account", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(AuthenticatorTheme.gradient, in: Capsule())
            }
            Spacer()
            Label("On this device. Ready offline.", systemImage: "checkmark.shield")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var unavailableState: some View {
        ContentUnavailableView {
            Label("Vault unavailable", systemImage: "lock.shield")
        } description: {
            Text("Unlock your device and try opening your local accounts again.")
        } actions: {
            Button("Try again") { store.reload() }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                AutoFillSetupView()
                Section("Codes") {
                    Toggle("Show next code", isOn: $showNextCode)
                }
                Section {
                    Label("Works without internet", systemImage: "wifi.slash")
                    Label("Saved in this device's Keychain", systemImage: "lock.shield")
                } header: {
                    Text("Local storage")
                } footer: {
                    Text("Accounts do not sync or transfer to another device. Keep the recovery codes provided by each service. Codes use your device's time.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSettings = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func copy(_ account: TOTPAccount, offset: Int = 0) {
        let now = Date.now
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: account.code(at: now, offset: offset)]], options: [
            .localOnly: true, .expirationDate: now.addingTimeInterval(Double(account.remaining(at: now) + offset * account.period))
        ])
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        copiedResetTask?.cancel()
        copiedID = account.id
        copiedResetTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            if copiedID == account.id { copiedID = nil }
        }
    }
}

struct AccountCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let account: TOTPAccount
    let date: Date
    var showNextCode = true
    var copied = false
    var onCopy: () -> Void

    private var remaining: Int { account.remaining(at: date) }
    private var countdownColor: Color {
        if remaining <= 5 { return .red }
        if remaining <= 10 { return .yellow }
        return AuthenticatorTheme.primary
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(String(account.title.prefix(1)).uppercased())
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(AuthenticatorTheme.gradient)
                    .frame(width: 44, height: 44)
                    .background(AuthenticatorTheme.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(AuthenticatorTheme.primary.opacity(0.16)) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.title).font(.system(size: 19, weight: .medium)).lineLimit(1)
                    if !account.issuer.isEmpty {
                        Text(account.issuer).font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle().stroke(countdownColor.opacity(0.12), lineWidth: 4)
                    Circle().trim(from: 0, to: CGFloat(remaining) / CGFloat(account.period))
                        .stroke(countdownColor.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(remaining)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(countdownColor)
                }
                .frame(width: 34, height: 34)
                .accessibilityLabel("\(remaining) seconds remaining")
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5)
            HStack(alignment: .center, spacing: 12) {
                Text(TOTPAccount.formatted(account.code(at: date)))
                    .font(.system(size: account.digits == 8 ? 29 : 34, weight: .semibold, design: .monospaced))
                    .tracking(1.3).lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(copied ? AuthenticatorTheme.primary : .primary)
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
                ZStack(alignment: .trailing) {
                    if copied {
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AuthenticatorTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AuthenticatorTheme.primary.opacity(0.10), in: Capsule())
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                    } else if showNextCode {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Next").font(.system(size: 13)).foregroundStyle(.secondary)
                            Text(TOTPAccount.formatted(account.code(at: date, offset: 1)))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                        }
                        .transition(.opacity)
                    }
                }
                .frame(minHeight: 36)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .glassSurface(radius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(AuthenticatorTheme.primary.opacity(copied ? 1 : 0), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.18) : .smooth(duration: 0.28), value: copied)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture(perform: onCopy)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to copy code. Long press for account options.")
    }
}

#Preview {
    ContentView()
}

#Preview("Account card") {
    AccountCard(account: TOTPAccount(title: "MyApp", secret: "JBSWY3DPEHPK3PXP", issuer: "M App"), date: .now, onCopy: {})
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AuthenticatorTheme.background(for: .light))
}
