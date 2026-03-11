//
//  SpaceListView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct SpaceListView: View {
    let spaces: [SpaceSwiftData]
    @Environment(\.dependencies) private var deps

    var onDelete: () -> Void = {}

    var body: some View {
        List {
            if spaces.isEmpty {
                Text("No spaces in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(spaces) { space in
                    NavigationLink {
                        SpaceDetailSettingsView(space: space)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(space.name)
                                    .font(.headline)

                                Spacer()

                                Text("Order: \(space.orderIndex)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("URL:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(space.urlString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let space = spaces[index]
                        deleteSpace(space)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func deleteSpace(_ space: SpaceSwiftData) {
        let deleteSpaceUseCase = DeleteSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        do {
            try deleteSpaceUseCase.execute(id: space.id)
            print("✅ Space deleted: \(space.id)")
            onDelete()
        } catch {
            print("❌ Error deleting space: \(error)")
        }
    }
}

#Preview("Space List") {
    let space = SpaceSwiftData(
        id: UUID(),
        name: "Preview Space",
        urlString: "https://example.com",
        defaultIdentityID: UUID(),
        orderIndex: 1,
        createdAt: .now,
        updatedAt: .now
    )

    SpaceListView(spaces: [space])
        .modelContainer(for: [SpaceSwiftData.self], inMemory: true)
}
