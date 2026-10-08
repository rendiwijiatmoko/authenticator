//
//  AccountStore.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import Foundation
import Observation
import Security

@Observable
final class AccountStore {
    private(set) var accounts: [TOTPAccount] = []
    var errorMessage: String?
    private(set) var isAvailable = false
    init() { reload() }

    func reload() {
        do {
            if let shared = try AutoFillVault.load() {
                accounts = shared
            } else {
                // Copy the original app-only vault only after the shared vault can be opened.
                let legacy = try AutoFillVault.load(shared: false) ?? []
                try AutoFillVault.save(legacy)
                accounts = legacy
            }
            isAvailable = true
        } catch {
            isAvailable = false
            errorMessage = "Unable to open your local vault. \(error.localizedDescription)"
        }
    }

    func add(_ account: TOTPAccount) throws {
        guard isAvailable else { throw AutoFillVaultError(status: errSecInteractionNotAllowed) }
        guard account.isValid else { throw AccountError.invalidSecret }
        guard !accounts.contains(where: {
            Base32.decode($0.secret) == Base32.decode(account.secret) && $0.title == account.title && $0.issuer == account.issuer
        }) else { throw AccountError.duplicate }
        try persist(accounts + [account])
    }

    func delete(_ account: TOTPAccount) {
        do { try persist(accounts.filter { $0.id != account.id }) }
        catch { errorMessage = error.localizedDescription }
    }

    func update(_ account: TOTPAccount) throws {
        guard isAvailable else { throw AutoFillVaultError(status: errSecInteractionNotAllowed) }
        guard account.isValid else { throw AccountError.unsupportedParameters }
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { throw AccountError.accountNotFound }
        guard !accounts.contains(where: {
            $0.id != account.id && Base32.decode($0.secret) == Base32.decode(account.secret) &&
            $0.title == account.title && $0.issuer == account.issuer
        }) else { throw AccountError.duplicate }
        var updated = accounts
        updated[index] = account
        try persist(updated)
    }

    private func persist(_ updated: [TOTPAccount]) throws {
        guard isAvailable else { throw AutoFillVaultError(status: errSecInteractionNotAllowed) }
        try AutoFillVault.save(updated)
        accounts = updated
    }
}
