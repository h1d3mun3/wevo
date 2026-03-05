//
//  IdentityKeyListView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct IdentityKeyListView: View {
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

                NavigationLink {
                    AddIdentityKeyView()
                } label: {
                    Text("Add IdentityKey")
                }
            }
            .navigationTitle("Identity Keys")
        }
    }
}

#Preview {
    IdentityKeyListView()
}
