//
//  IdentityKeyListView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct IdentityKeyListView: View {
    @State private var shouldShowCreateIdentityKey = false
    // TODO: Implement Later
    var items: [IdentityKey] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        // TODO: Implement Later
                        Text("Detail for \(item.nickname)")
                    } label: {
                        // TODO: Implement Later
                        Text(item.nickname)
                    }
                }

                Button(action: { shouldShowCreateIdentityKey = true }) {
                    Text("Create IdentityKey")
                }
            }
            .navigationTitle("IdentityKeys")
        }
        .sheet(isPresented: $shouldShowCreateIdentityKey) {
            CreateIdentityKeyView()
        }
    }
}

#Preview {
    IdentityKeyListView()
}
