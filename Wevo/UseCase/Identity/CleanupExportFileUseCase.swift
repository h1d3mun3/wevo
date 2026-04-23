//
//  CleanupExportFileUseCase.swift
//  Wevo
//

import Foundation

protocol CleanupExportFileUseCase {
    func execute(urls: [URL?])
}

struct CleanupExportFileUseCaseImpl: CleanupExportFileUseCase {
    func execute(urls: [URL?]) {
        for url in urls.compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
