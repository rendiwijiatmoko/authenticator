# Aster Auth

Aster Auth is an authenticator app for iPhone and iPad being prepared for the **Aster** organization. It generates time-based one-time passwords (TOTP), stores accounts in the device Keychain, and includes an OTP AutoFill extension.

**Status:** in development. Signing settings and bundle identifiers currently use the original developer's identity and need to be updated before distribution by Aster.

## Features

- Generate TOTP codes using SHA-1, SHA-256, and SHA-512.
- Support 6–8 digit codes with periods of 1–300 seconds; the default is 6 digits every 30 seconds.
- Add accounts by scanning a QR code with the camera, importing a QR code from a photo, entering details manually, or opening an `otpauth://totp/` link.
- Review accounts imported from setup links before saving them.
- Edit and delete accounts, and copy the current or next code.
- Display a countdown and optionally show the next code.
- Fill codes through the AutoFill extension with manual account selection.

HOTP and custom `encoder` parameters such as Steam are not supported. The extension provides OTP codes; automatic account matching to website domains is not available.

## Requirements

- macOS with Xcode and an SDK that supports the project's deployment target.
- Minimum iOS/iPadOS **26.0**, as currently configured in `Authenticator.xcodeproj`.
- An Apple development team with provisioning that supports Keychain Sharing and AutoFill Credential Provider for testing on a device.

The project uses SwiftUI, CryptoKit, Security, AVFoundation, Vision, PhotosUI, and AuthenticationServices. No third-party dependencies need to be installed.

## Getting Started

1. Open `Authenticator.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**, select the same development team for the `Authenticator` and `AuthenticatorAutoFill` targets.
3. Update the bundle identifiers and shared Keychain access group if using your organization's identity; see the Aster configuration section below.
4. Select the **Authenticator** scheme and a simulator or device that meets the deployment target.
5. Choose **Run** (`⌘R`). Allow camera access to scan QR codes.

The AutoFill target is already a dependency of the main app and is embedded in the app bundle. Test the camera and AutoFill integration on a physical device.

## Enabling AutoFill

1. Install and open the app once to initialize the shared vault.
2. Open Settings in the app and select **Set up AutoFill**. Alternatively, open **Settings → General → AutoFill & Passwords** on the device and enable **Aster Auth**.
3. To receive setup links or QR codes from the system, select **Aster Auth** under **Set Up Codes In** on the same page.
4. In an app or website that supports OTP AutoFill, choose Aster Auth and select the appropriate account.

System menu names and locations may vary by OS version or device language. Implementation and verification details are available in the [AutoFill documentation](autofill/README.md).

## Account Storage

Account secrets are stored in Keychain with `WhenUnlockedThisDeviceOnly` protection, and Keychain synchronization is disabled. The app and extension access the vault through a shared Keychain access group; the project does not use an App Group to share the vault.

If a legacy vault accessible only to the main app exists, the app copies it into the shared vault when no shared vault exists. The legacy vault is retained, while subsequent account changes use the shared vault.

Account backup, export, and synchronization across devices are not available yet. Keep recovery codes from your services before relying on the app for important accounts.

## Configuration for Aster

Current identifiers:

| Setting | Value |
| --- | --- |
| App bundle ID | `xyz.0xmwehehe.Authenticator` |
| Extension bundle ID | `xyz.0xmwehehe.Authenticator.autofill` |
| Shared Keychain group | `$(AppIdentifierPrefix)xyz.0xmwehehe.Authenticator.autofill` |

Before distributing the app under Aster's account:

1. Set the development team and bundle identifiers for both targets in Xcode. The extension bundle ID must use the main app's bundle ID as its prefix.
2. Keep the shared Keychain group consistent in `autofill/Authenticator.entitlements`, `autofill/AutoFill.entitlements`, and the `AutoFillKeychainAccessGroup` values in both Info.plist files.
3. Update `CFBundleURLName` in `autofill/Authenticator-Info.plist` to match the app's identity.
4. Review the Keychain service identifier in `autofill/Shared/AutoFillVault.swift`. Changes to the team, access group, or service require a migration plan if the app already has users.
5. Ensure provisioning for both targets includes the required entitlements, then verify vault access and OTP AutoFill on a physical device.

## Project Structure

```text
Authenticator/                 Main UI, account management, scanner, and TOTP
Authenticator.xcodeproj/       Targets, schemes, and build settings
autofill/                      AutoFill extension, setup UI, plists, and entitlements
autofill/Shared/AutoFillVault.swift
                               Keychain storage shared by both targets
Tests/TOTPTests.swift           Standalone TOTP tests
```

## Testing

Run from the project root on macOS with the Swift toolchain:

```sh
swiftc Authenticator/TOTPAccount.swift Tests/TOTPTests.swift -o /tmp/aster-auth-totp-tests
/tmp/aster-auth-totp-tests
```

The tests cover 18 RFC 6238 vectors across three algorithms, 6-digit codes, period rollover, next codes, Base32 validation, URI parsing, and account serialization. This file is a standalone executable and is not connected to an XCTest target in Xcode.

To verify integration, build the `Authenticator` scheme, then test adding accounts, persistence after reopening the app, editing and deleting accounts, and AutoFill on a device. Vault migration also needs to be tested from a previous installation with compatible signing.

## Contributing

Until organization guidelines are established, use a separate branch for changes and open a pull request describing the changes and verification results. Use clear commit messages, such as `feat: add account search` or `fix: handle invalid QR codes`.

Use sample accounts and secrets for testing. Do not include real credentials, recovery codes, or account QR codes in the repository, screenshots, or public issues.

## License

A license has not been selected yet. The Aster organization will determine whether the project is internal or public and establish its distribution terms.
