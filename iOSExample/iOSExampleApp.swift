//
//  iOSExampleApp.swift
//  iOSExample
//
//  Created by Andre Herculano on 15.02.24.
//

import SwiftUI
import SPDiagnose

@main
struct iOSExampleApp: App {
    @UIApplicationDelegateAdaptor(SPDiagnoseAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
