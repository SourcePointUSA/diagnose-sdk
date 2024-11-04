//
//  StateTest.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 8/8/24.
//

import Foundation
import XCTest
@testable import SPDiagnose

class StateTest: XCTestCase {
    override class func setUp() {
        // resets UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
    }

    func getState() -> SPDiagnose.State? {
        if let storedData = SPDiagnose.State.storage.data(forKey: SPDiagnose.State.StoreKeys.state.rawValue),
            let decoded = try? JSONDecoder().decode(SPDiagnose.State.self, from: storedData) {
            return decoded
        } else {
            return nil
        }
    }

    func testUpdateConsentStatusUpdatesConsentOnUserDefaults() {
        var state = SPDiagnose.State.shared
        XCTAssertEqual(state.consentStatus, .noAction)
        state.updateConsentStatus(.consentedAll)
        XCTAssertEqual(getState()?.consentStatus, .consentedAll)
    }
}
