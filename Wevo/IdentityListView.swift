//
//  IdentityListView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct IdentityListView: View {
    @State private var shouldShowCreateIdentity = false
    // TODO: Implement Later
    var identities: [Identity] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(identities) { item in
                    NavigationLink {
                        // TODO: Implement Later
                        Text("Detail for \(item.nickname)")
                    } label: {
                        // TODO: Implement Later
                        Text(item.nickname)
                    }
                }

                Button(action: { shouldShowCreateIdentity = true }) {
                    Text("Create Identity")
                }
            }
            .navigationTitle("Identity")
        }
        .sheet(isPresented: $shouldShowCreateIdentity) {
            CreateIdentityView()
        }
    }
}

#Preview {
    IdentityListView()
}
