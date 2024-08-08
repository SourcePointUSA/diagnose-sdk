//
//  NetworkSubscriberTests.swift
//  SPDiagnoseTests
//
//  Created by Andre Herculano on 8/8/24.
//

import Foundation
import XCTest
@testable import SPDiagnose

class NetworkSubscriberTests: XCTestCase {
    func postNotificationCenter(_ domain: String) {
        NotificationCenter.default.post(
            name: .SPDiagnoseNetworkIntercepted,
            object: nil,
            userInfo: ["domain": domain]
        )
    }

    func testItCallsOnNotification() {
        let expectation = XCTestExpectation(description: "Notification intercepted")
        let domain = "foo"

        /// even though XCode warns about `subscriber` not being used
        /// if replaced with `_` XCode will release the NetworkSubscriber
        /// causing the test to fail ¯\_(ツ)_/¯
        let subscriber = SPDiagnose.NetworkSubscriber { receivedDomain in
            if (receivedDomain == domain) {
                expectation.fulfill()
            } else {
                XCTFail("notification intercepted but with a different domain: \(receivedDomain as Any)")
            }
        }
        postNotificationCenter(domain)
        wait(for: [expectation], timeout: 5)
    }
}

