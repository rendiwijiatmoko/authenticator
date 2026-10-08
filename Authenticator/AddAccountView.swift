//
//  AddAccountView.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import SwiftUI
import PhotosUI
import Vision

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let store: AccountStore
    @State private var showManual = false
    @State private var scannedAccount: TOTPAccount?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var cameraMessage: String?
    @State private var importingPhoto = false

    var body: some View {
        GeometryReader { geometry in
            let scannerSize = geometry.size.width.isFinite ? max(0, min(geometry.size.width - 48, 360)) : 0
            ZStack {
                Color.black.ignoresSafeArea()
                QRScannerView(isScanning: scenePhase == .active && !showManual && errorMessage == nil && !importingPhoto, message: $cameraMessage) { receive($0) }
                    .ignoresSafeArea()
                Color.black.opacity(0.24).ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 28) {
                    Spacer()
                    ScannerCorners()
                        .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .square, lineJoin: .round))
                        .frame(width: scannerSize, height: scannerSize)
                        .accessibilityHidden(true)
                    Text(cameraMessage ?? "Point your camera at the\nQR code")
                        .font(.system(size: 25, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                    if cameraMessage?.contains("access is off") == true {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .foregroundStyle(.white).buttonStyle(.bordered)
                    }
                    Spacer()
                    HStack(spacing: 22) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 25, weight: .light)).frame(width: 44, height: 52)
                        }
                        .accessibilityLabel("Close scanner")
                        Button {
                            scannedAccount = nil
                            showManual = true
                        } label: {
                            Text("Enter manually")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity).frame(height: 56)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay { Capsule().strokeBorder(.white.opacity(0.25)) }
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 23)).frame(width: 44, height: 52)
                        }
                        .accessibilityLabel("Import QR code from photo")
                        .disabled(importingPhoto)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.bottom, 20)
                }
                if importingPhoto { ProgressView().tint(.white).padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            }
        }
        .sheet(isPresented: $showManual) {
            ManualEntryView(account: scannedAccount) { account in
                try store.add(account)
                showManual = false
                dismiss()
            }
        }
        .alert("Unable to add account", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            importingPhoto = true
            Task {
                defer { importingPhoto = false; selectedPhoto = nil }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw AccountError.invalidURI }
                    let request = VNDetectBarcodesRequest()
                    request.symbologies = [.qr]
                    try VNImageRequestHandler(data: data).perform([request])
                    let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
                    guard let account = payloads.compactMap({ try? TOTPAccount.parse(uri: $0) }).first else { throw AccountError.invalidURI }
                    scannedAccount = account
                    showManual = true
                } catch { errorMessage = error.localizedDescription }
            }
        }
    }

    private func receive(_ payload: String) {
        guard !showManual, errorMessage == nil else { return }
        do {
            scannedAccount = try TOTPAccount.parse(uri: payload)
            showManual = true
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = rect.width * 0.24
        var path = Path()
        for (x, y, dx, dy) in [(rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0),
                               (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0)] {
            path.move(to: CGPoint(x: x, y: y + dy * length))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx * length, y: y))
        }
        return path
    }
}

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String
    @State private var secret: String
    @State private var issuer: String
    @State private var digits: Int
    @State private var period: Int
    @State private var algorithm: TOTPAlgorithm
    @State private var errorMessage: String?
    let onSave: (TOTPAccount) throws -> Void
    private let accountID: UUID
    private let isEditing: Bool

    init(account: TOTPAccount? = nil, isEditing: Bool = false, onSave: @escaping (TOTPAccount) throws -> Void) {
        self.accountID = account?.id ?? UUID()
        self.isEditing = isEditing
        _title = State(initialValue: account?.title ?? "")
        _secret = State(initialValue: account?.secret ?? "")
        _issuer = State(initialValue: account?.issuer ?? "")
        _digits = State(initialValue: account?.digits ?? 6)
        _period = State(initialValue: account?.period ?? 30)
        _algorithm = State(initialValue: account?.algorithm ?? .sha1)
        self.onSave = onSave
    }

    private var account: TOTPAccount {
        TOTPAccount(id: accountID, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    secret: Base32.normalize(secret), issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
                    digits: digits, period: period, algorithm: algorithm)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .regular))
                        .frame(width: 46, height: 46).glassSurface(radius: 24)
                }
                .foregroundStyle(.primary).accessibilityLabel("Cancel")
                Spacer()
                Text(isEditing ? "Edit Account" : "New Entry").font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    do { try onSave(account) }
                    catch { errorMessage = error.localizedDescription }
                } label: {
                    Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(account.isValid ? .white : .secondary)
                        .frame(width: 46, height: 46)
                        .background {
                            if account.isValid { Circle().fill(AuthenticatorTheme.gradient) }
                            else { Circle().fill(.primary.opacity(0.09)) }
                        }
                }
                .disabled(!account.isValid).accessibilityLabel("Save account")
            }
            .padding(20)
            ScrollView {
                VStack(spacing: 12) {
                    entryField("Title (Required)", placeholder: "Title", text: $title)
                    entryField("Secret (Required)", placeholder: "Secret", text: $secret, isSecret: true)
                    entryField("Issuer", placeholder: "Issuer", text: $issuer)
                    VStack(spacing: 12) {
                        selectionRow("Digits") {
                            Picker("Digits", selection: $digits) {
                                ForEach(6...8, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .labelsHidden()
                        }
                        selectionRow("Time interval") {
                            Picker("Time interval", selection: $period) {
                                ForEach(Array(Set([15, 30, 60, period])).sorted(), id: \.self) {
                                    Text("\($0) seconds").tag($0)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(.top, 14)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALGORITHM").font(.caption).foregroundStyle(.secondary).padding(.leading, 16)
                        Picker("Algorithm", selection: $algorithm) {
                            ForEach(TOTPAlgorithm.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                    }
                    .padding(.top, 14)
                    HStack {
                        Text("TYPE").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("TOTP").font(.subheadline.weight(.semibold)).foregroundStyle(AuthenticatorTheme.primary)
                    }
                    .padding(18).glassSurface(radius: 24).padding(.top, 4)
                }
                .padding(.horizontal, 20).padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AuthenticatorTheme.background(for: colorScheme).ignoresSafeArea())
        .tint(AuthenticatorTheme.primary)
        .alert("Unable to save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func entryField(_ label: String, placeholder: String, text: Binding<String>, isSecret: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Group {
                if isSecret { SecureField(placeholder, text: text) }
                else { TextField(placeholder, text: text) }
            }
            .font(.system(size: 20))
            .textInputAutocapitalization(isSecret ? .characters : .never)
            .autocorrectionDisabled()
            .keyboardType(isSecret ? .asciiCapable : .default)
            .accessibilityLabel(label)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.10)) }
    }

    private func selectionRow<Selection: View>(_ label: String, @ViewBuilder selection: () -> Selection) -> some View {
        HStack {
            Text(label).font(.system(size: 18))
            Spacer()
            selection().tint(.primary)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .glassSurface(radius: 32)
    }
}

#Preview {
    ManualEntryView(onSave: { _ in })
}
