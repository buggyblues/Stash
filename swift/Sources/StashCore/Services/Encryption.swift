import CommonCrypto
import CryptoKit
import Foundation

/// The symmetric payload produced by the encryption helpers.
public struct EncryptedPayload: Codable, Equatable, Sendable {
    public var ciphertext: String
    public var iv: String
    public var tag: String
    public var salt: String

    public init(ciphertext: String, iv: String, tag: String, salt: String) {
        self.ciphertext = ciphertext
        self.iv = iv
        self.tag = tag
        self.salt = salt
    }
}

/// The encrypted form of a single clipboard item's content.
public struct ContentCiphertext: Codable, Equatable, Sendable {
    public var ciphertext: String
    public var iv: String
    public var tag: String

    public init(ciphertext: String, iv: String, tag: String) {
        self.ciphertext = ciphertext
        self.iv = iv
        self.tag = tag
    }
}

/// AES-256-GCM encryption with PBKDF2-HMAC-SHA512 key derivation.
///
/// The format is byte compatible with the previous Electron implementation so
/// that encrypted iCloud sync files can be exchanged between the two builds.
public enum Encryption {
    public static let keyLength = 32
    public static let ivLength = 16
    public static let saltLength = 32
    public static let pbkdf2Iterations: UInt32 = 100_000

    // MARK: - Key derivation

    public static func deriveKey(password: String, salt: Data) -> Data {
        var derived = [UInt8](repeating: 0, count: keyLength)
        let passwordBytes = Array(password.utf8)
        let saltBytes = [UInt8](salt)

        let status = passwordBytes.withUnsafeBufferPointer { passwordBuffer in
            saltBytes.withUnsafeBufferPointer { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress, passwordBuffer.count,
                    saltBuffer.baseAddress, saltBuffer.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                    pbkdf2Iterations,
                    &derived, derived.count
                )
            }
        }

        guard status == kCCSuccess else {
            // Should never happen: the inputs are always valid.
            return Data(derived)
        }
        return Data(derived)
    }

    public static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        }
        return Data(bytes)
    }

    // MARK: - Raw encryption

    public static func encrypt(_ plaintext: String, key: Data) throws -> ContentCiphertext {
        let nonceData = generateSalt(count: ivLength)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: SymmetricKey(data: key), nonce: nonce)
        return ContentCiphertext(
            ciphertext: sealed.ciphertext.base64EncodedString(),
            iv: nonceData.base64EncodedString(),
            tag: sealed.tag.base64EncodedString()
        )
    }

    public static func decrypt(_ payload: ContentCiphertext, key: Data) throws -> String {
        guard let nonceData = Data(base64Encoded: payload.iv),
              let ciphertext = Data(base64Encoded: payload.ciphertext),
              let tag = Data(base64Encoded: payload.tag)
        else {
            throw EncryptionError.invalidPayload
        }
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let opened = try AES.GCM.open(box, using: SymmetricKey(data: key))
        guard let text = String(data: opened, encoding: .utf8) else {
            throw EncryptionError.invalidPayload
        }
        return text
    }

    // MARK: - Password based payloads (used by the sync files)

    public static func encryptWithPassword(_ plaintext: String, password: String) throws -> EncryptedPayload {
        let salt = generateSalt()
        let key = deriveKey(password: password, salt: salt)
        let cipher = try encrypt(plaintext, key: key)
        return EncryptedPayload(
            ciphertext: cipher.ciphertext,
            iv: cipher.iv,
            tag: cipher.tag,
            salt: salt.base64EncodedString()
        )
    }

    public static func decryptWithPassword(_ payload: EncryptedPayload, password: String) throws -> String {
        guard let salt = Data(base64Encoded: payload.salt) else {
            throw EncryptionError.invalidPayload
        }
        let key = deriveKey(password: password, salt: salt)
        return try decrypt(
            ContentCiphertext(ciphertext: payload.ciphertext, iv: payload.iv, tag: payload.tag),
            key: key
        )
    }

    // MARK: - Helpers

    private static func generateSalt(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        }
        return Data(bytes)
    }
}

/// Errors raised by the encryption helpers.
public enum EncryptionError: Error, CustomStringConvertible {
    case invalidPayload
    case decryptionFailed

    public var description: String {
        switch self {
        case .invalidPayload: return "The encrypted payload is malformed."
        case .decryptionFailed: return "The payload could not be decrypted."
        }
    }
}

/// Holds the in-memory content encryption key, mirroring the previous
/// `security/encryption.ts` module.
public final class ContentEncryptor {
    private var cachedKey: Data?
    private var cachedSalt: Data?
    private let lock = NSLock()

    public init() {}

    public var isKeySet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cachedKey != nil
    }

    public func setPassword(_ password: String, salt: Data? = nil) {
        let resolvedSalt = salt ?? Encryption.generateSalt()
        let key = Encryption.deriveKey(password: password, salt: resolvedSalt)
        lock.lock()
        cachedSalt = resolvedSalt
        cachedKey = key
        lock.unlock()
    }

    public func clearKey() {
        lock.lock()
        cachedKey = nil
        cachedSalt = nil
        lock.unlock()
    }

    public var saltBase64: String? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSalt?.base64EncodedString()
    }

    /// Encrypts content for storage; returns `nil` when no key is configured.
    public func encryptContent(_ plaintext: String) -> String? {
        lock.lock()
        let key = cachedKey
        lock.unlock()
        guard let key else { return nil }
        guard let cipher = try? Encryption.encrypt(plaintext, key: key),
              let data = try? JSONEncoder().encode(cipher),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }

    /// Decrypts stored content; returns `nil` when no key is configured or the
    /// payload is unreadable.
    public func decryptContent(_ encryptedJSON: String) -> String? {
        lock.lock()
        let key = cachedKey
        lock.unlock()
        guard let key else { return nil }
        guard let data = encryptedJSON.data(using: .utf8),
              let cipher = try? JSONDecoder().decode(ContentCiphertext.self, from: data),
              let plaintext = try? Encryption.decrypt(cipher, key: key)
        else { return nil }
        return plaintext
    }
}
