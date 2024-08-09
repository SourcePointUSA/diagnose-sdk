//
//  UserDefaults+SPDiagnose.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 9/8/24.
//

import Foundation

extension UserDefaults {
    func boolOrNil(forKey defaultName: String) -> Bool? {
        dictionaryRepresentation().keys.contains(defaultName) ?
            bool(forKey: defaultName) :
            nil
    }
}
