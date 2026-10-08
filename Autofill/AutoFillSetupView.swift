//
//  AutoFillSetupView.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import AuthenticationServices
import SwiftUI

struct AutoFillSetupView: View {
    @State private var isEnabled = false
    @State private var isRequesting = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            Label(isEnabled ? "AutoFill enabled" : "AutoFill verification codes", systemImage: "key.fill")
            if !isEnabled {
                Button("Set up AutoFill") {
                    isRequesting = true
                    ASSettingsHelper.requestToTurnOnCredentialProviderExtension { _ in
                        Task { @MainActor in
                            isRequesting = false
                            refresh()
                        }
                    }
                }
                .disabled(isRequesting)
            }
        } header: {
            Text("AutoFill")
        } footer: {
            Text("Enable Aster Auth in Settings → General → AutoFill & Passwords. When a verification code field offers AutoFill, choose an account to fill its current code.")
        }
        .task { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    private func refresh() {
        ASCredentialIdentityStore.shared.getState { state in
            Task { @MainActor in isEnabled = state.isEnabled }
        }
    }
}
