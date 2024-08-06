//
//  SPHttpClient.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 6/8/24.
//

import Foundation

protocol HttpClient {
    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response
}

class SPHttpClient: HttpClient {
    let auth: String
    let logger: SPLogger.Type

    lazy var encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return enc
    }()

    lazy var decoder: JSONDecoder = {
        return JSONDecoder()
    }()

    init(auth: String, logger: SPLogger.Type = SPLogger.self) {
        self.auth = auth
        self.logger = logger
    }

    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization")

        do {
            let body = try encoder.encode(body)
            request.httpBody = body
            logger.log(String(data: body, encoding: .utf8) ?? "")
        } catch {
            throw error
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let responseData = try? decoder.decode(Response.self, from: data) {
            return responseData
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
}
