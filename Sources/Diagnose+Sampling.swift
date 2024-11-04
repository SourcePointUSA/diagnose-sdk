//
//  Diagnose+Sampling.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 8/8/24.
//

import Foundation

extension SPDiagnose {

    public enum ConsentStatus: String, Codable {
        case noAction, consentedAll, consentedSome, rejectedAll
    }

    struct State: Codable, CustomStringConvertible {
        struct Sampling: Codable, CustomStringConvertible {
            /// pick a random number from 0 to 100 if the number picked is smaller than `rate`
            /// return `true` otherwise
            /// return `false`
            static func sampleIt(rate: Int) -> Bool {
                return 0...Int(rate) ~= Int.random(in: 0...100)
            }

            var rate: Int
            var hit: Bool?

            var description: String {
                "Sampling(rate: \(rate)%, hit: \(hit?.description ?? ""))"
            }

            mutating func updateAndSample(newRate: Int){
                if newRate != rate {
                    rate = newRate
                    hit = Self.sampleIt(rate: newRate)
                }
            }
        }

        static let shared = State()
        static let storage = UserDefaults.standard

        public enum StoreKeys: String {
            case state = "sp.diagnose.state"
        }

        var sampling: Sampling = Sampling(rate: 0)
        var diagnoseAccountId, diagnosePropertyId: String?
        var expireOn: Date?
        var consentStatus: ConsentStatus = .noAction

        var description: String {
            """
            State(
                sampling: \(sampling),
                diagnoseAccountId: \(diagnoseAccountId ?? ""),
                diagnosePropertyId: \(diagnosePropertyId ?? ""),
                expireOn: \(expireOn?.description ?? ""),
                consentStatus: \(consentStatus)
            )
            """
        }

        private init() {
            if let storedData = Self.storage.data(forKey: Self.StoreKeys.state.rawValue),
               let decoded = try? JSONDecoder().decode(Self.self, from: storedData)
            {
                SPLogger.log("Stored state: \(decoded)")
                logSamplingState()
                self = decoded
            }
        }

        func persist() {
            SPLogger.log("Persisting state: \(self)")
            logSamplingState()
            Self.storage.setValue(
                try? JSONEncoder().encode(self),
                forKey: Self.StoreKeys.state.rawValue
            )
            Self.storage.synchronize()
        }

        mutating func updateConsentStatus(_ status: SPDiagnose.ConsentStatus) {
            consentStatus = status
            persist()
        }

        func logSamplingState() {
            if sampling.hit == true {
                SPLogger.log("Network requests will be captured and sent to Sourcepoint Diagnose Service, because the current user was sampled in.")
            } else {
                SPLogger.log("Network requests will be captured but NOT sent to Sourcepoint Diagnose Service, because the current user was sampled out.")
            }
        }
    }
}

