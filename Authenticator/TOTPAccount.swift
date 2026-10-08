//
//  TOTPAccount.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import Foundation
import CryptoKit

enum TOTPAlgorithm: String, CaseIterable, Codable, Identifiable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    var id: String { rawValue }
}

struct TOTPAccount: Identifiable, Codable {
    var id = UUID()
    var title: String
    var secret: String
    var issuer: String
    var digits: Int = 6
    var period: Int = 30
    var algorithm: TOTPAlgorithm = .sha1

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Base32.decode(secret) != nil && (6...8).contains(digits) && (1...300).contains(period)
    }

    func code(at date: Date, offset: Int = 0) -> String {
        guard isValid, let data = Base32.decode(secret) else { return String(repeating: "–", count: digits) }
        let seconds = max(0, date.timeIntervalSince1970)
        var counter = (UInt64(seconds / Double(period)) + UInt64(max(0, offset))).bigEndian
        let message = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: data)
        let hash: [UInt8]
        switch algorithm {
        case .sha1: hash = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: hash = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: hash = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let start = Int(hash[hash.count - 1] & 0x0f)
        let number = (UInt32(hash[start] & 0x7f) << 24) |
            (UInt32(hash[start + 1]) << 16) |
            (UInt32(hash[start + 2]) << 8) | UInt32(hash[start + 3])
        let modulus = UInt32(pow(10, Double(digits)))
        return String(format: "%0*d", digits, number % modulus)
    }

    func remaining(at date: Date) -> Int {
        period - Int(max(0, date.timeIntervalSince1970)) % period
    }

    static func formatted(_ code: String) -> String {
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<middle]) \(code[middle...])"
    }

    static func parse(uri: String) throws -> TOTPAccount {
        guard let components = URLComponents(string: uri.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "otpauth",
              components.host?.lowercased() == "totp" else {
            throw AccountError.invalidURI
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name.lowercased() == name }?.value }
        guard value("encoder") == nil else { throw AccountError.unsupportedParameters }
        guard let secret = value("secret") else { throw AccountError.invalidSecret }
        let label = String(components.path.dropFirst())
        let parts = label.split(separator: ":", maxSplits: 1).map(String.init)
        let issuer = value("issuer") ?? (parts.count == 2 ? parts[0] : "")
        guard let digits = Int(value("digits") ?? "6"),
              let period = Int(value("period") ?? "30"),
              let algorithm = TOTPAlgorithm(rawValue: (value("algorithm") ?? "SHA1").uppercased()) else {
            throw AccountError.unsupportedParameters
        }
        let account = TOTPAccount(title: parts.last ?? "", secret: Base32.normalize(secret), issuer: issuer,
                                  digits: digits, period: period, algorithm: algorithm)
        guard account.isValid else { throw AccountError.unsupportedParameters }
        return account
    }
}

enum AccountError: LocalizedError {
    case invalidURI, invalidSecret, unsupportedParameters, duplicate, accountNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURI: "This QR code is not a TOTP account. Use an otpauth://totp QR code."
        case .invalidSecret: "Enter a valid Base32 secret using letters A–Z and numbers 2–7."
        case .unsupportedParameters: "Check the account title, secret, digits (6–8), period (1–300), and algorithm."
        case .duplicate: "This account is already in your authenticator."
        case .accountNotFound: "This account no longer exists in your authenticator."
        }
    }
}

enum Base32 {
    static func normalize(_ string: String) -> String {
        string.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    static func decode(_ string: String) -> Data? {
        let normalized = normalize(string)
        let unpadded = normalized.prefix { $0 != "=" }
        let padding = normalized.dropFirst(unpadded.count)
        guard !unpadded.isEmpty, padding.allSatisfy({ $0 == "=" }),
              [0, 2, 4, 5, 7].contains(unpadded.count % 8),
              padding.isEmpty || (normalized.count % 8 == 0 && padding.count < 7) else { return nil }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var buffer: UInt32 = 0
        var bits = 0
        var bytes = Data()
        for character in unpadded {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> bits) & 0xff))
                buffer &= (1 << bits) - 1
            }
        }
        guard buffer == 0, !bytes.isEmpty else { return nil }
        return bytes
    }
}
