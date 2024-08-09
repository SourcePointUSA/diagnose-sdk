//
//  NetworkLoggerTests.swift
//  SPDiagnoseTests
//
//  Created by Andre Herculano on 8/8/24.
//

import Foundation

import XCTest
@testable import SPDiagnose

class NetworkLoggerTests: XCTestCase {
    override func setUpWithError() throws {
        URLSessionConfiguration.default.protocolClasses?.append(SPDiagnose.NetworkLogger.self)
    }

    override func tearDownWithError() throws {}

    func request(_ domain: String) {
        URLSession(configuration: .default)
            .dataTask(
                with: URLRequest(url: URL(string: "https://\(domain)")!)
            )
            .resume()
    }

    func observeNotificationCenter(handler: @escaping (Notification) -> Void) {
        NotificationCenter.default.addObserver(
            forName: .SPDiagnoseNetworkIntercepted,
            object: nil,
            queue: OperationQueue.main,
            using: handler
        )
    }

    func testItPostsToNotificationCenterOnEachNetworkRequest() throws {
        let domain = "sourcepoint.com"
        let expectation = XCTestExpectation(description: "NotificationCenter notified")
        observeNotificationCenter {
            let notifiedDomain = $0.userInfo?["domain"] as? String
            if notifiedDomain == domain {
                expectation.fulfill()
            }
        }

        request(domain)
        wait(for: [expectation], timeout: 5)
    }
}

