//
//  iOSExampleApp.swift
//  iOSExample
//
//  Created by Andre Herculano on 15.02.24.
//

import SwiftUI
import SPDiagnose

func sendRequestTo(_ url: String) {
    guard let url = URL(string: url) else { return }
    URLSession(configuration: .default)
        .dataTask(with: URLRequest(url: url))
        .resume()
}

@main
struct iOSExampleApp: App {
    @UIApplicationDelegateAdaptor(SPDiagnoseAppDelegate.self) var appDelegate

    @State var consentStatus: SPDiagnose.ConsentStatus = .noAction

    func updateConsent(status: SPDiagnose.ConsentStatus) {
        consentStatus = status
        appDelegate.diagnose.updateConsent(status: status)
    }

    init() {
        _consentStatus = State(initialValue: appDelegate.diagnose.consentStatus)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                networkRequest: { sendRequestTo("https://sourcepoint.com") },
                acceptAll: { updateConsent(status: .consentedAll) },
                acceptSome: { updateConsent(status: .consentedSome) },
                rejectAll: { updateConsent(status: .rejectedAll) },
                resetStatus: { updateConsent(status: .noAction) },
                currentStatus: consentStatus.rawValue
            )
        }
    }
}
