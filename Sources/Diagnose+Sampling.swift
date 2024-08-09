//
//  Diagnose+Sampling.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 8/8/24.
//

import Foundation

extension SPDiagnose {
    struct Sampling {
        static let shared = Sampling()

        /// pick a random number from 0 to 100 if the number picked is smaller than `rate`
        /// return `true` otherwise
        /// return `false`
        static func sampleIt(rate: Int) -> Bool {
            return 0...Int(rate) ~= Int.random(in: 0...100)
        }

        let storage = UserDefaults.standard

        public enum StoreKeys: String {
            case rate = "sp.diagnose.sampling.rate"
            case hit = "sp.diagnose.sampling.hit"
        }

        private init() {}

        var rate: Int {
            get { storage.integer(forKey: StoreKeys.rate.rawValue) }
        }
        var hit: Bool? {
            get { storage.boolOrNil(forKey: StoreKeys.hit.rawValue) }
        }

        func setRate(_ newValue: Int){
            storage.set(newValue, forKey: StoreKeys.rate.rawValue)
        }

        func setHit(_ newValue: Bool?) {
            storage.set(newValue, forKey: StoreKeys.hit.rawValue)
        }

        func updateAndSample(newRate: Int) -> Bool? {
            if newRate != rate {
                setRate(newRate)
                setHit(Self.sampleIt(rate: newRate))
            }
            return hit
        }
    }
}

