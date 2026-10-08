//
//  TOTPTests.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import Foundation

// Compile with TOTPAccount.swift to run independently of the simulator.
@main
struct TOTPTests {
    static func main() throws {
        let times: [TimeInterval] = [59, 1_111_111_109, 1_111_111_111, 1_234_567_890, 2_000_000_000, 20_000_000_000]
        let vectors: [(TOTPAlgorithm, String, [String])] = [
            (.sha1, "12345678901234567890", ["94287082", "07081804", "14050471", "89005924", "69279037", "65353130"]),
            (.sha256, "12345678901234567890123456789012", ["46119246", "68084774", "67062674", "91819424", "90698825", "77737706"]),
            (.sha512, "1234567890123456789012345678901234567890123456789012345678901234", ["90693936", "25091201", "99943326", "93441116", "38618901", "47863826"])
        ]
        for (algorithm, key, expected) in vectors {
            let account = TOTPAccount(title: "RFC vector", secret: encode(Data(key.utf8)), issuer: "RFC 6238", digits: 8, algorithm: algorithm)
            for (time, value) in zip(times, expected) {
                precondition(account.code(at: Date(timeIntervalSince1970: time)) == value, "RFC vector failed: \(algorithm) at \(time)")
            }
        }
        let account = TOTPAccount(title: "Test", secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", issuer: "")
        precondition(account.code(at: Date(timeIntervalSince1970: 59)) == "287082")
        precondition(account.remaining(at: Date(timeIntervalSince1970: 59)) == 1)
        precondition(account.remaining(at: Date(timeIntervalSince1970: 60)) == 30)
        precondition(account.code(at: Date(timeIntervalSince1970: 59), offset: 1) == account.code(at: Date(timeIntervalSince1970: 60)))
        precondition(Base32.decode("mzxw6===") == Data("foo".utf8))
        precondition(Base32.decode("MZ======") == nil) // Nonzero unused bits.
        for invalid in ["", "A", "ABC", "00000000", "MY=AAAAA", "MY=====", "MY======="] {
            precondition(Base32.decode(invalid) == nil, "Invalid Base32 accepted")
        }
        let uri = "otpauth://totp/Example:hello%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256&digits=8&period=60"
        let parsed = try TOTPAccount.parse(uri: uri)
        precondition(parsed.title == "hello@example.com" && parsed.issuer == "Example")
        precondition(parsed.algorithm == .sha256 && parsed.digits == 8 && parsed.period == 60)
        for invalid in ["https://example.com", "otpauth://hotp/Test?secret=MY======", "otpauth://totp/Test?secret=bad!", "otpauth://totp/Test?secret=MY======&period=0", "otpauth://totp/Test?secret=MY======&algorithm=MD5", "otpauth://totp/Test?secret=MY======&digits=5", "otpauth://totp/Test?secret=MY======&encoder=steam"] {
            do {
                _ = try TOTPAccount.parse(uri: invalid)
                preconditionFailure("Invalid URI accepted")
            } catch {}
        }
        let restored = try JSONDecoder().decode(TOTPAccount.self, from: JSONEncoder().encode(parsed))
        precondition(restored.id == parsed.id && restored.code(at: Date(timeIntervalSince1970: 59)) == parsed.code(at: Date(timeIntervalSince1970: 59)))
        print("Passed: 18 RFC 6238 vectors, 6-digit codes, rollover, next code, Base32 validation, URI parsing, and Codable round trip.")
    }

    static func encode(_ data: Data) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0
        var buffer = 0
        var result = ""
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                result.append(alphabet[(buffer >> bits) & 31])
            }
            buffer &= (1 << bits) - 1
        }
        if bits > 0 { result.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return result
    }
}
