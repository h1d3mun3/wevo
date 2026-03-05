//
//  Space.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation

struct Space {
    let id: UUID
    let name: String
    let serverURL: URLRequest
    let activeIdentityID: UUID?
    let orderIndex: Int
}
