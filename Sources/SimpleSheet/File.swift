//
//  File.swift
//  
//
//  Created by Charles Vu on 08/02/2022.
//

import Foundation

enum HTTPMethod {
    case post
    case get
}

class HTTPProxy {
    static func execute<T: Decodable, U: Encodable>(
        on client: URLSession,
        url: URL,
        headers: [String: String],
        body: U,
        method: HTTPMethod = .get) async throws -> T {
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = headers
            request.httpBody = try JSONEncoder().encode(body)
            request.httpMethod = method == .post ? "POST" : "GET"
            let (data, _) = try await client.data(for: request)

            print("  > " + url.absoluteString)
            print("  < " + String(data: data, encoding: .utf8)!)

            return try JSONDecoder().decode(T.self, from: data)

        }

    static func execute<T: Decodable>(
        on client: URLSession,
        url: URL,
        headers: [String: String],
        method: HTTPMethod = .get) async throws -> T {
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = headers
            request.httpMethod = method == .post ? "POST" : "GET"
            let (data, _) = try await client.data(for: request)

            print("  > " + url.absoluteString)
            print("  < " + String(data: data, encoding: .utf8)!)

            return try JSONDecoder().decode(T.self, from: data)

        }

}
