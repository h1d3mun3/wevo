//
//  AddSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol AddSpaceUseCase {
    func execute(name: String, urlString: String, defaultIdentityID: UUID?) throws
}

struct AddSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository

    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
}

extension AddSpaceUseCaseImpl: AddSpaceUseCase {
    func execute(name: String, urlString: String, defaultIdentityID: UUID?) throws {
        // URLの妥当性チェック（オプショナル）
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 既存のSpaceの数を取得してorderIndexを決定
        let orderIndex: Int
        do {
            let existingSpaces = try spaceRepository.fetchAll()
            orderIndex = existingSpaces.count
        } catch {
            print("❌ Error fetching spaces: \(error)")
            orderIndex = 0
        }

        // Spaceエンティティの作成
        let space = Space(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: trimmedURL,
            defaultIdentityID: defaultIdentityID,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )

        // SwiftDataに保存
        try spaceRepository.create(space)
        print("✅ Space saved: \(space.name)")
    }
}
