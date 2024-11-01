//
//  SPHttpClient.swift
//  SPDiagnose
//
//  Created by Andre Herculano on 6/8/24.
//

import Foundation

protocol HttpClient {
    init(auth: String, logger: SPLogger.Type)
    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response
    func post<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response
    func get<Response: Decodable>(_ url: URL) async throws -> Response
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

    required init(auth: String, logger: SPLogger.Type = SPLogger.self) {
        self.auth = auth
        self.logger = logger
    }

    func parseResponse<Response: Decodable>(_ reqResponse: (Data, URLResponse)) throws -> Response {
        let (data, response) = reqResponse
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        if let responseData = try? decoder.decode(Response.self, from: data) {
            logger.log("response - \(httpResponse.url?.absoluteString ?? "")")
            logger.log(String(data: data, encoding: .utf8) ?? "<empty response>")
            return responseData
        } else {
            throw URLError(.cannotParseResponse)
        }
    }

    func put<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        let encodedBody = try encoder.encode(body)
        logger.log("request - PUT \(url.absoluteString)")
        logger.log(String(data: encodedBody, encoding: .utf8) ?? "")

        return try parseResponse(
            try await URLSession.shared.data(
                for: URLRequest(url: url, method: "PUT", bearer: auth, body: encodedBody)
            )
        )
    }

    func get<Response: Decodable>(_ url: URL) async throws -> Response {
        logger.log("request - GET \(url.absoluteString)")

        return try parseResponse(
            try await URLSession.shared.data(for: URLRequest(url: url, bearer: auth))
        )
    }

    func post<Body: Encodable, Response: Decodable>(_ url: URL, body: Body) async throws -> Response {
        let encodedBody = try encoder.encode(body)
        logger.log("request - POST \(url.absoluteString)")
        logger.log(String(data: encodedBody, encoding: .utf8) ?? "")

        return try parseResponse(
            try await URLSession.shared.data(for: URLRequest(url: url, method: "POST", bearer: auth, body: encodedBody))
        )
    }
}

extension URLRequest {
    init(url: URL, method: String = "GET", bearer: String, body: Data? = nil) {
        self.init(url: url)
        httpMethod = method
        setValue("application/json", forHTTPHeaderField: "Content-Type")
        setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        httpBody = body
    }
}
