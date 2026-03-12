//
//  Contact.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

struct Contact: Identifiable {
    let id: UUID
    var nickname: String
    var publicKey: String
    let createdAt: Date
}
