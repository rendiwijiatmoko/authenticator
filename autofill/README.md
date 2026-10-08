# AutoFill extension

All AutoFill implementation and configuration lives in this folder.

- `CredentialProviderViewController.swift`: system entry point and searchable OTP account picker.
- `AutoFillSetupView.swift`: setup section displayed by the main app's Settings screen.
- `Shared/AutoFillVault.swift`: shared, device-only Keychain storage, compiled into both targets.
- `Info.plist`: extension entry point and one-time-code capability.
- `Authenticator-Info.plist`: app display name, `otpauth` setup URL registration, and shared Keychain group configuration merged into the main app’s generated plist.
- `AutoFill.entitlements`: credential provider capability and shared Keychain group.
- `Authenticator.entitlements`: main app's original Keychain group plus the shared group.

The `AuthenticatorAutoFill` target is a dependency of the main app and is embedded in its PlugIns directory. It also compiles the existing `Authenticator/TOTPAccount.swift` so both targets use the same OTP implementation.

## Device setup

1. Use the same signing team for both targets. The provisioning profiles must include the configured Keychain groups and the extension's AutoFill Credential Provider capability.
2. Install the app and open it once. The main app copies its existing vault into the shared Keychain group only when no shared vault exists. The original vault remains intact; subsequent account changes use the shared vault.
3. Open the app's Settings and tap **Set up AutoFill**, or enable Aster Auth in **Settings → General → AutoFill & Passwords**.
4. For setup links and QR codes, select **Aster Auth** under **Set Up Codes In** on the same Settings page. Incoming `otpauth://totp/` links open the account form for review before saving. HOTP and unsupported parameters show an error.
5. In an app or website that offers OTP AutoFill, choose Aster Auth, select an account, and verify that its current code is filled.

Only OTP credentials are provided. Account selection is manual: issuer names are not treated as website domains, and credentials are not indexed for automatic website suggestions. Secrets stay in Keychain with `WhenUnlockedThisDeviceOnly` protection.

## Verification

Build the `Authenticator` scheme to compile both targets and check extension embedding. Real-device activation, shared Keychain migration from an existing signed installation, and filling an OTP field must also be checked with valid provisioning profiles.
