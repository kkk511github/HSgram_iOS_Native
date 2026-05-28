import CommonCrypto
import CryptoKit
import Foundation
import Security

enum HSNativeMTProtoCryptoError: LocalizedError {
    case aesFailed(CCCryptorStatus)
    case badLength(String)
    case badPublicKey
    case rsaUnsupported
    case rsaFailed(String)

    var errorDescription: String? {
        switch self {
        case .aesFailed(let status):
            return "AES-IGE 计算失败：\(status)。"
        case .badLength(let message):
            return message
        case .badPublicKey:
            return "HSgram MTProto RSA 公钥无法解析。"
        case .rsaUnsupported:
            return "当前系统不支持 MTProto 需要的 raw RSA 加密。"
        case .rsaFailed(let message):
            return "RSA 加密失败：\(message)"
        }
    }
}

enum HSNativeMTProtoCrypto {
    static let serverPublicKeyFingerprint: Int64 = -6205835210776354611

    static let serverPublicKeyPEM = """
    -----BEGIN RSA PUBLIC KEY-----
    MIIBCgKCAQEAvKLEOWTzt9Hn3/9Kdp/RdHcEhzmd8xXeLSpHIIzaXTLJDw8BhJy1
    jR/iqeG8Je5yrtVabqMSkA6ltIpgylH///FojMsX1BHu4EPYOXQgB0qOi6kr08iX
    ZIH9/iOPQOWDsL+Lt8gDG0xBy+sPe/2ZHdzKMjX6O9B4sOsxjFrk5qDoWDrioJor
    AJ7eFAfPpOBf2w73ohXudSrJE0lbQ8pCWNpMY8cB9i8r+WBitcvouLDAvmtnTX7a
    khoDzmKgpJBYliAY4qA73v7u5UIepE8QgV0jCOhxJCPubP8dg+/PlLLVKyxU5Cdi
    QtZj2EMy4s9xlNKzX8XezE0MHEa6bQpnFwIDAQAB
    -----END RSA PUBLIC KEY-----
    """

    static func sha1(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    static func temporaryAESKeyAndIV(newNonce: Data, serverNonce: Data) throws -> (key: Data, iv: Data) {
        guard newNonce.count == 32, serverNonce.count == 16 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto temporary AES key requires 32-byte new_nonce and 16-byte server_nonce.")
        }
        let sha1A = sha1(newNonce + serverNonce)
        let sha1B = sha1(serverNonce + newNonce)
        let sha1C = sha1(newNonce + newNonce)

        var keyAndIV = Data()
        keyAndIV.append(sha1A)
        keyAndIV.append(sha1B)
        keyAndIV.append(sha1C)
        keyAndIV.append(newNonce.prefix(4))
        return (keyAndIV.prefixData(32), keyAndIV.suffixData(32))
    }

    static func authKeyID(authKey: Data) throws -> Int64 {
        guard authKey.count == 256 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto auth_key must be 256 bytes.")
        }
        let digest = sha1(authKey)
        let value = UInt64(digest[12])
            | (UInt64(digest[13]) << 8)
            | (UInt64(digest[14]) << 16)
            | (UInt64(digest[15]) << 24)
            | (UInt64(digest[16]) << 32)
            | (UInt64(digest[17]) << 40)
            | (UInt64(digest[18]) << 48)
            | (UInt64(digest[19]) << 56)
        return Int64(bitPattern: value)
    }

    static func newNonceHash(newNonce: Data, authKey: Data, variant: UInt8) throws -> Data {
        guard newNonce.count == 32, authKey.count == 256 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto new_nonce_hash requires 32-byte new_nonce and 256-byte auth_key.")
        }
        let authKeyDigest = sha1(authKey)
        let digest = sha1(newNonce + Data([variant]) + authKeyDigest.prefixData(8))
        return digest.suffixData(16)
    }

    static func serverSalt(newNonce: Data, serverNonce: Data) throws -> Int64 {
        guard newNonce.count == 32, serverNonce.count == 16 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto server salt requires 32-byte new_nonce and 16-byte server_nonce.")
        }
        var value: Int64 = 0
        for index in stride(from: 7, through: 0, by: -1) {
            value <<= 8
            value |= Int64(newNonce[index] ^ serverNonce[index])
        }
        return value
    }

    static func encryptPQInnerData(_ innerData: Data, randomPadding: Data, tempKey: Data) throws -> Data {
        guard innerData.count <= 144 else {
            throw HSNativeMTProtoCryptoError.badLength("p_q_inner_data must not exceed 144 bytes before RSA padding.")
        }
        guard randomPadding.count == 192 - innerData.count else {
            throw HSNativeMTProtoCryptoError.badLength("RSA padding must make p_q_inner_data exactly 192 bytes.")
        }
        guard tempKey.count == 32 else {
            throw HSNativeMTProtoCryptoError.badLength("RSA temp key must be 32 bytes.")
        }

        let dataWithPadding = innerData + randomPadding
        let reversed = Data(dataWithPadding.reversed())
        let hash = sha256(tempKey + dataWithPadding)
        let dataWithHash = reversed + hash
        let aesEncrypted = try aesIGE(dataWithHash, key: tempKey, iv: Data(repeating: 0, count: 32), operation: CCOperation(kCCEncrypt))
        let encryptedHash = sha256(aesEncrypted)
        let adjustedKey = xor(tempKey, encryptedHash)
        return try rsaRawEncrypt(adjustedKey + aesEncrypted)
    }

    static func aesIGE(_ data: Data, key: Data, iv: Data, operation: CCOperation) throws -> Data {
        guard data.count % kCCBlockSizeAES128 == 0 else {
            throw HSNativeMTProtoCryptoError.badLength("AES-IGE input length must be a multiple of 16 bytes.")
        }
        guard key.count == kCCKeySizeAES256, iv.count == 32 else {
            throw HSNativeMTProtoCryptoError.badLength("AES-IGE requires a 32-byte key and 32-byte IV.")
        }

        var result = Data()
        result.reserveCapacity(data.count)
        var previousCipher = iv.prefixData(16)
        var previousPlain = iv.suffixData(16)

        for offset in stride(from: 0, to: data.count, by: kCCBlockSizeAES128) {
            let block = data.subdata(in: offset..<(offset + kCCBlockSizeAES128))
            if operation == CCOperation(kCCEncrypt) {
                let xored = xor(block, previousCipher)
                let encrypted = try aesECBBlock(xored, key: key, operation: operation)
                let cipher = xor(encrypted, previousPlain)
                result.append(cipher)
                previousCipher = cipher
                previousPlain = block
            } else {
                let xored = xor(block, previousPlain)
                let decrypted = try aesECBBlock(xored, key: key, operation: operation)
                let plain = xor(decrypted, previousCipher)
                result.append(plain)
                previousCipher = block
                previousPlain = plain
            }
        }

        return result
    }

    static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        precondition(lhs.count == rhs.count)
        return Data(zip(lhs, rhs).map { $0 ^ $1 })
    }

    private static func aesECBBlock(_ block: Data, key: Data, operation: CCOperation) throws -> Data {
        guard block.count == kCCBlockSizeAES128 else {
            throw HSNativeMTProtoCryptoError.badLength("AES block size must be 16 bytes.")
        }
        var output = Data(count: kCCBlockSizeAES128)
        let outputCapacity = output.count
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            block.withUnsafeBytes { blockBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyBytes.baseAddress,
                        key.count,
                        nil,
                        blockBytes.baseAddress,
                        block.count,
                        outputBytes.baseAddress,
                        outputCapacity,
                        &outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw HSNativeMTProtoCryptoError.aesFailed(status)
        }
        return output.prefixData(outputLength)
    }

    private static func rsaRawEncrypt(_ data: Data) throws -> Data {
        guard data.count == 256 else {
            throw HSNativeMTProtoCryptoError.badLength("Raw RSA input must be 256 bytes.")
        }
        guard let key = publicKey() else {
            throw HSNativeMTProtoCryptoError.badPublicKey
        }
        let algorithm = SecKeyAlgorithm.rsaEncryptionRaw
        guard SecKeyIsAlgorithmSupported(key, .encrypt, algorithm) else {
            throw HSNativeMTProtoCryptoError.rsaUnsupported
        }
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(key, algorithm, data as CFData, &error) as Data? else {
            let message = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            throw HSNativeMTProtoCryptoError.rsaFailed(message)
        }
        return encrypted
    }

    private static func publicKey() -> SecKey? {
        let base64 = serverPublicKeyPEM
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()
        guard let der = Data(base64Encoded: base64) else {
            return nil
        }
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: 2048
        ]
        return SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil)
    }
}

private extension Data {
    func prefixData(_ count: Int) -> Data {
        Data(prefix(count))
    }

    func suffixData(_ count: Int) -> Data {
        Data(suffix(count))
    }
}
