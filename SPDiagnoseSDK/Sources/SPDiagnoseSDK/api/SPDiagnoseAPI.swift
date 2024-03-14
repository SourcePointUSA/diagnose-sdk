//
//  SPDiagnoseAPI.swift
//  
//
//  Created by Andre Herculano on 16.02.24.
//

import Foundation

class SPNetworkClient {
    // TODO: inject as dependency
    var auth = SPConfig.key ?? ""

    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
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

struct SendEventRequest: Encodable {
    struct Event: Encodable {
        let ts: Int
        let domain: String
        let type: String = ""
        let valid: Bool = true
        let tcString: String?
    }
    let eventsLarge: [Event]
}

struct SendEventResponse: Decodable {}

@objcMembers class SPDiagnoseAPI: NSObject {
    var baseUrl: URL { URL(string: "https://6pst9lv2dd.execute-api.eu-west-2.amazonaws.com")! }
    var eventsUrl: URL { URL(string: "/stage/recordEvents/", relativeTo: baseUrl)! }

    func getConfig() {
        NSLog("DiagnoseAPI: getConfig()")
    }

    func sendEvent(_ event: SPDiagnose.Event) async {

        switch event {
            case .network(let domain, let tcString):
                let _: SendEventResponse? = try? await SPNetworkClient()
                    .put(eventsUrl,
                        body: SendEventRequest(
                            eventsLarge: [
                                .init(
                                    ts: Int(Date.now.timeIntervalSince1970),
                                    domain: domain,
                                    tcString: tcString
                                )
                            ]
                        )
                    )
        }
    }
}
