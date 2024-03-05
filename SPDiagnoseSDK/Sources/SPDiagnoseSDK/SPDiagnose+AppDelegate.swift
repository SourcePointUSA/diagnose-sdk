//
//  File.swift
//  
//
//  Created by Andre Herculano on 16.02.24.
//

import Foundation
import UIKit

public class SPDiagnoseAppDelegate: NSObject, UIApplicationDelegate {
    var diagnose: SPDiagnose?

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        diagnose = SPDiagnose()
        return true
    }
}
