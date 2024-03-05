//
//  File.swift
//  
//
//  Created by Andre Herculano on 16.02.24.
//

import Foundation

class NetworkClient {
    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6InZhZGltLnBAZ293b21iYXQudGVhbSIsImV4cCI6MTcxMjkyNTk5N30.dTH4nyVS6UZzFWo57yArvG1YVGyYWr_Cv7NfBZP--e8", forHTTPHeaderField: "Authorization")

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
    func getConfig() {
        NSLog("DiagnoseAPI: getConfig()")
    }

    func sendEvent(_ event: SPDiagnose.Event) async {
        switch event {
            case .network(let domain, let tcString):
                let _: SendEventResponse? = try? await NetworkClient()
                    .put(
                        URL(string: "https://6pst9lv2dd.execute-api.eu-west-2.amazonaws.com/stage/recordEvents/")!,
                        body: SendEventRequest(
                            eventsLarge: [
                                .init(ts: 999, domain: domain, tcString: tcString)
                            ]
                        )
                    )
        }
    }
}
