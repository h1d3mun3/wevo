//
//  ContactRepositoryTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
import SwiftData
@testable import Wevo

@MainActor
struct ContactRepositoryTests {

    let container: ModelContainer
    let repo: ContactRepositoryImpl

    init() throws {
        let schema = Schema([ContactSwiftData.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        repo = ContactRepositoryImpl(modelContext: container.mainContext)
    }

    private func makeContact(
        nickname: String = "Alice",
        publicKey: String = "samplePublicKey",
        createdAt: Date = .now
    ) -> Contact {
        Contact(id: UUID(), nickname: nickname, publicKey: publicKey, createdAt: createdAt)
    }

    // MARK: - create

    @Test func testCreate_storesContact() throws {
        let contact = makeContact(nickname: "Alice")

        try repo.create(contact)

        let all = try repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].id == contact.id)
        #expect(all[0].nickname == "Alice")
    }

    @Test func testCreate_storesMultipleContacts() throws {
        try repo.create(makeContact(nickname: "Alice"))
        try repo.create(makeContact(nickname: "Bob"))

        let all = try repo.fetchAll()
        #expect(all.count == 2)
    }

    // MARK: - fetchAll

    @Test func testFetchAll_returnsEmpty_whenNoContacts() throws {
        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test func testFetchAll_returnsSortedByCreatedAt() throws {
        let older = Contact(id: UUID(), nickname: "Older", publicKey: "pk1", createdAt: Date(timeIntervalSinceNow: -100))
        let newer = Contact(id: UUID(), nickname: "Newer", publicKey: "pk2", createdAt: .now)

        // 意図的に新しい順で登録
        try repo.create(newer)
        try repo.create(older)

        let all = try repo.fetchAll()

        // createdAt 昇順（古い方が先）
        #expect(all.count == 2)
        #expect(all[0].nickname == "Older")
        #expect(all[1].nickname == "Newer")
    }

    // MARK: - fetch(by id:)

    @Test func testFetchByID_returnsCorrectContact() throws {
        let contact = makeContact(nickname: "Alice")
        try repo.create(contact)

        let fetched = try repo.fetch(by: contact.id)

        #expect(fetched.id == contact.id)
        #expect(fetched.nickname == "Alice")
        #expect(fetched.publicKey == contact.publicKey)
    }

    @Test func testFetchByID_throwsContactNotFound_whenMissing() throws {
        #expect(throws: (any Error).self) {
            _ = try repo.fetch(by: UUID())
        }
    }

    // MARK: - update

    @Test func testUpdate_modifiesNicknameAndPublicKey() throws {
        let contact = makeContact(nickname: "Alice", publicKey: "oldKey")
        try repo.create(contact)

        let updated = Contact(id: contact.id, nickname: "Alice Updated", publicKey: "newKey", createdAt: contact.createdAt)
        try repo.update(updated)

        let fetched = try repo.fetch(by: contact.id)
        #expect(fetched.nickname == "Alice Updated")
        #expect(fetched.publicKey == "newKey")
    }

    @Test func testUpdate_throwsContactNotFound_whenMissing() throws {
        #expect(throws: (any Error).self) {
            try repo.update(makeContact())
        }
    }

    // MARK: - delete

    @Test func testDelete_removesContact() throws {
        let contact = makeContact(nickname: "Alice")
        try repo.create(contact)

        try repo.delete(by: contact.id)

        #expect(try repo.fetchAll().isEmpty)
    }

    @Test func testDelete_doesNotAffectOtherContacts() throws {
        let c1 = makeContact(nickname: "Alice")
        let c2 = makeContact(nickname: "Bob")
        try repo.create(c1)
        try repo.create(c2)

        try repo.delete(by: c1.id)

        let all = try repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].id == c2.id)
    }

    @Test func testDelete_throwsContactNotFound_whenMissing() throws {
        #expect(throws: (any Error).self) {
            try repo.delete(by: UUID())
        }
    }
}
