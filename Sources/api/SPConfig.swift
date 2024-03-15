//
//  SPConfig.swift
//  
//
//  Created by Andre Herculano on 05.03.24.
//

import Foundation

enum SPDiagnoseError: Error {
    case configNotFound(_ message: String)
    case unableToParseConfig(_ message: String)
}

struct SPConfig: Codable {
    init() throws {
        guard let path = Bundle.main.path(forResource: "SPDiagnoseConfig", ofType: "plist")
        else {
            throw SPDiagnoseError.configNotFound("Couldn't initialise DiagnoseSDK config. Make sure SPDiagnoseConfig.plist exists in the root folder of your project")
        }
        do {
            let data = try Data(contentsOf: NSURL.fileURL(withPath: path))
            let decoder = PropertyListDecoder()
            self = try decoder.decode(Self.self, from: data)
        } catch {
            throw SPDiagnoseError.unableToParseConfig(error.localizedDescription)
        }
    }

    let key: String
}
