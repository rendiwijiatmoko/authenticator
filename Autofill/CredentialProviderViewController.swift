//
//  CredentialProviderViewController.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import AuthenticationServices
import SwiftUI

final class CredentialProviderViewController: ASCredentialProviderViewController {
    private var hostingController: UIViewController?

    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        showAccounts()
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        guard credentialRequest is ASOneTimeCodeCredentialRequest else {
            cancel(.failed)
            return
        }
        do {
            let accounts = try AutoFillVault.load() ?? []
            guard let account = accounts.first(where: { $0.id.uuidString == credentialRequest.credentialIdentity.recordIdentifier }) else {
                cancel(.credentialIdentityNotFound)
                return
            }
            complete(account)
        } catch {
            cancel(.userInteractionRequired)
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        guard credentialRequest is ASOneTimeCodeCredentialRequest else {
            cancel(.failed)
            return
        }
        showAccounts(recordIdentifier: credentialRequest.credentialIdentity.recordIdentifier)
    }

    override func prepareInterfaceForExtensionConfiguration() {
        show(AutoFillConfigurationView { [weak self] in
            self?.extensionContext.completeExtensionConfigurationRequest()
        })
    }

    private func showAccounts(recordIdentifier: String? = nil) {
        do {
            var accounts = try AutoFillVault.load() ?? []
            if let recordIdentifier {
                accounts = accounts.filter { $0.id.uuidString == recordIdentifier }
                guard !accounts.isEmpty else {
                    cancel(.credentialIdentityNotFound)
                    return
                }
            }
            show(AutoFillAccountList(accounts: accounts, errorMessage: nil, select: { [weak self] account in
                self?.complete(account)
            }, cancel: { [weak self] in self?.cancel(.userCanceled) }))
        } catch {
            show(AutoFillAccountList(accounts: [], errorMessage: "Unlock your device and open Aster Auth to access your accounts.",
                                     select: { _ in }, cancel: { [weak self] in self?.cancel(.userCanceled) }))
        }
    }

    private func complete(_ account: TOTPAccount) {
        // Generate at selection time so the returned code isn't a stale displayed value.
        extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: account.code(at: .now)))
    }

    private func cancel(_ code: ASExtensionError.Code) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: code.rawValue))
    }

    private func show<Content: View>(_ content: Content) {
        if let old = hostingController {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        let controller = UIHostingController(rootView: content)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }
}

private struct AutoFillAccountList: View {
    let accounts: [TOTPAccount]
    let errorMessage: String?
    let select: (TOTPAccount) -> Void
    let cancel: () -> Void
    @State private var search = ""

    private var filtered: [TOTPAccount] {
        accounts.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.issuer.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let errorMessage {
                    ContentUnavailableView("Vault unavailable", systemImage: "lock.shield", description: Text(errorMessage))
                } else if accounts.isEmpty {
                    ContentUnavailableView("No accounts yet", systemImage: "key", description: Text("Open Aster Auth to add your first account."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    List(filtered) { account in
                        Button { select(account) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.title).font(.headline)
                                if !account.issuer.isEmpty { Text(account.issuer).font(.subheadline).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose an OTP account")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) } }
        }
    }
}

private struct AutoFillConfigurationView: View {
    let done: () -> Void
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Aster Auth AutoFill", systemImage: "key.fill", description: Text("Add accounts in Aster Auth, then choose Aster Auth when filling a verification code."))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) } }
        }
    }
}
