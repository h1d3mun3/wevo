//
//  ImportFileReading.swift
//  Wevo
//

import Foundation

enum ImportFileError: Error, LocalizedError {
    case tooLarge
    var errorDescription: String? { "The file is too large to import." }
}

/// Reads a to-be-imported `.wevo-*` document into memory with an upper size bound, so a malicious
/// or corrupt file cannot exhaust memory. These documents are only a few KB in practice.
func readImportData(from url: URL, maxBytes: Int = 1_048_576) throws -> Data {
    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxBytes {
        throw ImportFileError.tooLarge
    }
    let data = try Data(contentsOf: url)
    guard data.count <= maxBytes else { throw ImportFileError.tooLarge }
    return data
}
