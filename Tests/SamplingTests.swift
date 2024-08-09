//
//  SamplingTests.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 8/8/24.
//

import Foundation
import XCTest
@testable import SPDiagnose

class SamplingTests: XCTestCase {
    override class func setUp() {
        // resets UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
    }

    func testGettingSettingRateWorks() {
        let storage = UserDefaults.standard
        let key = SPDiagnose.Sampling.StoreKeys.rate.rawValue

        SPDiagnose.Sampling.shared.setRate(0)
        assert(storage.integer(forKey: key) == 0)
        SPDiagnose.Sampling.shared.setRate(10)
        assert(storage.integer(forKey: key) == 10)
    }

    func testGettingSettingHitWorks() {
        let storage = UserDefaults.standard
        let key = SPDiagnose.Sampling.StoreKeys.hit.rawValue

        SPDiagnose.Sampling.shared.setHit(nil)
        XCTAssertNil(storage.value(forKey: key))
        
        SPDiagnose.Sampling.shared.setHit(false)
        XCTAssertFalse(storage.bool(forKey: key))
        
        SPDiagnose.Sampling.shared.setHit(true)
        XCTAssertTrue(storage.bool(forKey: key))
    }
}
