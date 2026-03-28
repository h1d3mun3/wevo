//
//  SignatureBlock.swift
//  WevoShareExtension
//

import Foundation

enum SignatureBlock {
    static let separator = "\n\n---\nWevo Signature\n"

    static func contains(_ text: String) -> Bool {
        text.contains(separator)
    }

    static func format(text: String, publicKeyBase64: String, signatureBase64: String) -> String {
        "\(text)\(separator)Public Key: \(publicKeyBase64)\nSignature: \(signatureBase64)"
    }

    /// Returns (originalText, publicKey base64, signature base64) or nil if not parseable.
    static func parse(_ fullText: String) -> (originalText: String, publicKey: String, signature: String)? {
        guard let range = fullText.range(of: separator) else { return nil }
        let original = String(fullText[..<range.lowerBound])
        let rest = String(fullText[range.upperBound...])

        var publicKey: String?
        var signature: String?
        for line in rest.components(separatedBy: "\n") {
            if line.hasPrefix("Public Key: ") {
                publicKey = String(line.dropFirst("Public Key: ".count))
            } else if line.hasPrefix("Signature: ") {
                signature = String(line.dropFirst("Signature: ".count))
            }
        }
        guard let pk = publicKey, let sig = signature else { return nil }
        return (original, pk, sig)
    }
}
