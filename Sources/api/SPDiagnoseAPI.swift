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

struct GetMetaDataResponse: Decodable {
    let samplingRate: Int
}

@objcMembers class SPDiagnoseAPI: NSObject {
    let accountId, propertyId: Int
    let appName: String?
    lazy var sessionId = UUID()

    var client: HttpClient
    var logger: SPLogger.Type?

    public static var baseUrl: URL { URL(string: "https://compliance-api.sp-redbud.com")! }
    static var eventsUrl: URL { URL(string: "/recordEvents/?_version=1.0.70", relativeTo: baseUrl)! }
    static var metaDataBaseUrl: URL { URL(string: "/meta-data/?_version=1.0.70", relativeTo: baseUrl)! }

    var metaDataUrl: URL {
        Self.metaDataBaseUrl.appending(params: [
            "accountId": String(accountId),
            "propertyId": String(propertyId),
            "appName": appName
        ])!
    }

    init(
        accountId: Int,
        propertyId: Int,
        appName: String?,
        key: String,
        client: HttpClient? = nil,
        logger: SPLogger.Type = SPLogger.self
    ) {
        self.accountId = accountId
        self.propertyId = propertyId
        self.appName = appName
        guard let client = client else {
            self.client = SPHttpClient(auth: key)
            return
        }
        self.client = client
        self.logger = logger
    }

    func getConfig() {
        logger?.log("DiagnoseAPI.getConfig()")
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

    func getMetaData() async throws -> GetMetaDataResponse {
        do {
            return try await client.get(metaDataUrl)
        } catch {
            SPLogger.log("failed to getMetaData: \(error.localizedDescription)")
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
