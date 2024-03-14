//
//  SPLogger.swift
//  
//
//  Created by Andre Herculano on 05.03.24.
//

import Foundation
import os

struct SPLogger {
    static var tag = "SPDiagnose"

    static var osLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "", category: .pointsOfInterest)

    static func log(_ message: String) {
        os_log("[%s] %s", log: osLogger, type: .default, tag, message)
    }
}
