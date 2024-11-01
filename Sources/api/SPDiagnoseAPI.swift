//
//  SPDiagnoseAPI.swift
//  
//
//  Created by Andre Herculano on 16.02.24.
//

import Foundation

enum Event: Encodable {
    case network(ts: Int, data: NetworkEventData, type: String = "network")
    case consent(ts: Int, data: ConsentEventData, type: String = "consent")

    enum NetworkCodingKeys: CodingKey {
        case ts, data, type
    }

    enum ConsentCodingKeys: CodingKey {
        case ts, data, type
    }

    func encode(to encoder: Encoder) throws {
        switch self {
            case .network(let ts, let data, let type):
                var container = encoder.container(keyedBy: NetworkCodingKeys.self)
                try container.encode(ts, forKey: NetworkCodingKeys.ts)
                try container.encode(data, forKey: NetworkCodingKeys.data)
                try container.encode(type, forKey: NetworkCodingKeys.type)
            case .consent(let ts, let data, let type):
                var container = encoder.container(keyedBy: ConsentCodingKeys.self)
                try container.encode(ts, forKey: ConsentCodingKeys.ts)
                try container.encode(data, forKey: ConsentCodingKeys.data)
                try container.encode(type, forKey: ConsentCodingKeys.type)
        }
    }
}

struct NetworkEventData: Encodable {
    let domain: String
    let gdprTCString: String?
}

struct ConsentEventData: Encodable {
    let consentAction: SPDiagnose.ConsentAction
}

struct SendEventRequest: Encodable {
    let accountId, propertyId: Int
    let appName: String?
    let events: [Event]
    let sessionId: UUID
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
    let diagnoseAccountId, diagnosePropertyId: String?
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
        diagnoseAccountId: String?,
        diagnosePropertyId: String?,
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
        self.diagnoseAccountId = diagnoseAccountId
        self.diagnosePropertyId = diagnosePropertyId
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
            switch event {
                case .network(let domain, let tcString): 
                    events.append(
                        .network(
                            ts: timestamp,
                            data: .init(
                                domain: domain,
                                gdprTCString: tcString
                            )
                        )
                    )
                case .consent(let action):
                    events.append(
                        .consent(
                            ts: timestamp,
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
                    events: events,
                    sessionId: sessionId
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
