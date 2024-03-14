//
//  SPConfig.swift
//  
//
//  Created by Andre Herculano on 05.03.24.
//

import Foundation

struct SPConfig {
    private static let plistName = "SPDiagnoseConfig"

    private static func getValue(name: String) -> String? {
        if let path = Bundle.main.path(forResource: "SPDiagnoseConfig", ofType: "plist") {
            return NSDictionary(contentsOfFile: path)?[name] as? String
        }
        return nil
    }

    static var key: String? { getValue(name: "key") }
}
