//
//  SPDiagnoseAPI.swift
//  
//
//  Created by Andre Herculano on 16.02.24.
//

import Foundation

enum Event: Encodable {
    case network(ts: Int, sessionId: UUID, requestCount: Int, consentStatus: SPDiagnose.ConsentStatus, data: NetworkEventData, type: String = "network")
    case consent(ts: Int, sessionId: UUID, requestCount: Int, consentStatus: SPDiagnose.ConsentStatus, data: ConsentEventData, type: String = "consent")

    enum NetworkCodingKeys: String, CodingKey {
        case ts, data, type, sessionId
        case consentStatus = "consent_status"
        case requestCount = "req"
    }

    enum ConsentCodingKeys: String, CodingKey {
        case ts, data, type, sessionId
        case consentStatus = "consent_status"
        case requestCount = "req"
    }

    func encode(to encoder: Encoder) throws {
        switch self {
            case .network(let ts, let sessionId, let requestCount, let consentStatus, let data, let type):
                var container = encoder.container(keyedBy: NetworkCodingKeys.self)
                try container.encode(ts, forKey: .ts)
                try container.encode(data, forKey: .data)
                try container.encode(type, forKey: .type)
                try container.encode(sessionId, forKey: .sessionId)
                try container.encode(requestCount, forKey: .requestCount)
                try container.encode(consentStatus, forKey: .consentStatus)
            case .consent(let ts, let sessionId, let requestCount, let consentStatus, let data, let type):
                var container = encoder.container(keyedBy: ConsentCodingKeys.self)
                try container.encode(ts, forKey: .ts)
                try container.encode(data, forKey: .data)
                try container.encode(type, forKey: .type)
                try container.encode(sessionId, forKey: .sessionId)
                try container.encode(requestCount, forKey: .requestCount)
                try container.encode(consentStatus, forKey: .consentStatus)
        }
    }
}

struct NetworkEventData: Encodable {
    let domain: String
    let gdprTCString: String?
    let sampleRate: Float
}

struct ConsentEventData: Encodable {
    let consentAction: SPDiagnose.ConsentAction
}

struct SendEventRequest: Encodable {
    let accountId, propertyId: Int
    let appName, diagnoseAccountId, diagnosePropertyId: String?
    let events: [Event]
}

struct SendEventResponse: Decodable {}

struct GetConfigResponse: Decodable {
    let data: GetConfigData

    struct GetConfigData: Decodable {
        let diagnoseAccountId: String?
        let diagnosePropertyId: String?

        private let expireOnString: String?
        var expireOn: Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let expireOnString = expireOnString,
               let parsedDate = formatter.date(from: expireOnString) {
                return parsedDate
            }
            return nil
        }

        private let sampleRateString: String?
        var samplingRate: Int {
            if let sampleRateString = sampleRateString,
               let doubleValue = Double(sampleRateString)
            {
                let percentageValue = doubleValue * 100
                let valueBetweenZeroAndHundred = min(max(percentageValue, 0), 100)
                return Int(valueBetweenZeroAndHundred)
            } else {
                print("DiagnoseSDK: samplingRate missing in config, defaulting to 0.")
                return 0
            }
        }

        init(diagnoseAccountId: String? = nil, diagnosePropertyId: String? = nil, expireOnString: String? = nil, sampleRateString: String? = nil) {
            self.diagnoseAccountId = diagnoseAccountId
            self.diagnosePropertyId = diagnosePropertyId
            self.expireOnString = expireOnString
            self.sampleRateString = sampleRateString
        }

        init(from decoder: any Decoder) throws {
            let dataContainer = try? decoder.container(keyedBy: CodingKeys.self)
            diagnoseAccountId = try dataContainer?.decodeIfPresent(String.self, forKey: .diagnoseAccountId)
            diagnosePropertyId = try dataContainer?.decodeIfPresent(String.self, forKey: .diagnosePropertyId)
            sampleRateString = try dataContainer?.decodeIfPresent(String.self, forKey: .sampleRateString)
            expireOnString = try dataContainer?.decodeIfPresent(String.self, forKey: .expireOnString)
        }

        private enum CodingKeys: String, CodingKey {
            case diagnoseAccountId = "diagnoseaccountid"
            case diagnosePropertyId = "diagnosepropertyid"
            case expireOnString = "expire_on"
            case sampleRateString = "sample_rate"
        }
    }
}

struct GetConfigRequest: Encodable {
    let accountId, propertyId: Int
    let apiKey: String
}

@objcMembers class SPDiagnoseAPI: NSObject {
    let accountId, propertyId: Int
    let state: SPDiagnose.State
    let authKey: String
    let appName: String?
    let sessionId = UUID()
    var consentStatus: SPDiagnose.ConsentStatus
    var requestCount = 0

    var client: HttpClient
    var logger: SPLogger.Type?

    public static var baseUrl: URL { URL(string: "https://sdk.sp-redbud.com/app/")! }
    static var eventsUrl: URL { URL(string: "./recordEvents/", relativeTo: baseUrl)! }
    static var getConfigUrl: URL { URL(string: "./getConfig/", relativeTo: baseUrl)! }

    init(
        accountId: Int,
        propertyId: Int,
        appName: String?,
        state: SPDiagnose.State,
        consentStatus: SPDiagnose.ConsentStatus,
        key: String,
        client: HttpClient? = nil,
        logger: SPLogger.Type = SPLogger.self
    ) {
        self.accountId = accountId
        self.propertyId = propertyId
        self.appName = appName
        self.consentStatus = consentStatus
        self.authKey = key
        self.state = state
        guard let client = client else {
            self.client = SPHttpClient(auth: key)
            return
        }
        self.client = client
        self.logger = logger
    }

    func sendEvent(_ event: SPDiagnose.Event) async {
        do {
            var events: [Event] = []
            let timestamp = Int(Date.now.timeIntervalSince1970)
            requestCount += 1
            switch event {
                case .network(let domain, let tcString): 
                    events.append(
                        .network(
                            ts: timestamp,
                            sessionId: sessionId,
                            requestCount: requestCount,
                            consentStatus: consentStatus,
                            data: .init(
                                domain: domain,
                                gdprTCString: tcString,
                                sampleRate: Float(state.sampling.rate) / 100.0
                            )
                        )
                    )
                case .consent(let action):
                    events.append(
                        .consent(
                            ts: timestamp,
                            sessionId: sessionId,
                            requestCount: requestCount,
                            consentStatus: consentStatus,
                            data: .init(consentAction: action)
                        )
                    )
            }
            let _: SendEventResponse? = try await client.put(
                Self.eventsUrl,
                body: SendEventRequest(
                    accountId: accountId,
                    propertyId: propertyId,
                    appName: appName,
                    diagnoseAccountId: state.diagnoseAccountId,
                    diagnosePropertyId: state.diagnosePropertyId,
                    events: events
                )
            )
        } catch {
            logger?.log("failed to sendEvent: \(error.localizedDescription)")
        }
    }

    func getConfig() async throws -> GetConfigResponse {
        do {
            return try await client.post(Self.getConfigUrl, body: GetConfigRequest(
                accountId: accountId,
                propertyId: propertyId,
                apiKey: authKey
            ))
        } catch {
            SPLogger.log("failed to getConfig: \(error.localizedDescription)")
            throw error
        }
    }
}

extension URL {
    func appending(params: [String: String?]) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        params.forEach {
            components?.queryItems?.append(URLQueryItem(name: $0.key, value: $0.value))
        }
        return components?.url
    }
}
