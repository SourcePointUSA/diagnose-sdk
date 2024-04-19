//
//  SPDiagnoseAPI.swift
//  
//
//  Created by Andre Herculano on 16.02.24.
//

import Foundation

class SPNetworkClient {
    let auth: String

    init(auth: String) {
        self.auth = auth
    }

    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
        do {
            let encoder = JSONEncoder()
            let body = try encoder.encode(body)
            request.httpBody = body
            SPLogger.log(String(data: body, encoding: .utf8) ?? "")
        } catch {
            throw error
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        if let responseData = try? decoder.decode(Response.self, from: data) {
            return responseData
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
}

enum Event: Encodable {
    case network(ts: Int, data: NetworkEvent, type: String = "network")

    enum NetworkCodingKeys: CodingKey {
        case ts
        case data
        case type
    }

    func encode(to encoder: Encoder) throws {
        switch self {
            case .network(let ts, let data, let type):
                var container = encoder.container(keyedBy: NetworkCodingKeys.self)
                try container.encode(ts, forKey: NetworkCodingKeys.ts)
                try container.encode(data, forKey: NetworkCodingKeys.data)
                try container.encode(type, forKey: NetworkCodingKeys.type)
        }
    }
}

struct NetworkEvent: Encodable {
    let domain: String
    let gdprTCString: String?
}

struct SendEventRequest: Encodable {
    let accountId, propertyId: Int
    let appName: String?
    let events: [Event]
}

struct SendEventResponse: Decodable {}

@objcMembers class SPDiagnoseAPI: NSObject {
    let accountId, propertyId: Int
    let appName: String?

    var client: SPNetworkClient

    var baseUrl: URL {
        URL(string: "https://compliance-api.sp-redbud.com")!
    }
    var eventsUrl: URL {
        URL(string: "/recordEvents/?_version=1.0.70", relativeTo: baseUrl)!
    }

    init(
        accountId: Int,
        propertyId: Int,
        appName: String?,
        key: String,
        client: SPNetworkClient? = nil
    ) {
        self.accountId = accountId
        self.propertyId = propertyId
        self.appName = appName
        guard let client = client else {
            self.client = SPNetworkClient(auth: key)
            return
        }
        self.client = client
    }

    func getConfig() {
        SPLogger.log("DiagnoseAPI.getConfig()")
    }

    func sendEvent(_ event: SPDiagnose.Event) async {
        do {
            switch event {
                case .network(let domain, let tcString):
                    let _: SendEventResponse? = try await client
                        .put(eventsUrl,
                             body: SendEventRequest(
                                accountId: accountId,
                                propertyId: propertyId,
                                appName: appName,
                                events: [
                                    .network(
                                        ts: Int(Date.now.timeIntervalSince1970),
                                        data: .init(
                                            domain: domain,
                                            gdprTCString: tcString
                                        )
                                    )
                                ]
                             )
                        )
            }
        } catch {
            SPLogger.log("failed to sendEvent: \( error.localizedDescription)")
        }
    }
}
