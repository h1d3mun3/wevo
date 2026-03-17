//
//  Logger+Extensions.swift
//  Wevo
//

import os

extension Logger {
    private static let subsystem = "com.wevo"

    static let app      = Logger(subsystem: subsystem, category: "app")
    static let identity = Logger(subsystem: subsystem, category: "identity")
    static let propose  = Logger(subsystem: subsystem, category: "propose")
    static let space    = Logger(subsystem: subsystem, category: "space")
    static let contact  = Logger(subsystem: subsystem, category: "contact")
    static let ui       = Logger(subsystem: subsystem, category: "ui")
}
