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
    static var defaultDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.dataDecodingStrategy = .custom({ (decoder) -> Data in
            let container = try decoder.singleValueContainer()
            let decodedStr = try container.decode(String.self) // URL decode
                            .replacingOccurrences(of: "_", with: "/")
                            .replacingOccurrences(of: "-", with: "+")
            if let data = Data(base64Encoded: decodedStr) {
                return data
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data corrupted")
        })
        return decoder
    }()

    static var defaultEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.dataEncodingStrategy = .base64
        return encoder
    }()

    static func execute<T: Decodable, U: Encodable>(
        on client: URLSession,
        url: URL,
        headers: [String: String],
        parameters: [String: String],
        body: U,
        method: HTTPMethod = .get) async throws -> T {

            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

            for (key, value) in parameters {
                if components?.queryItems == nil {
                    components?.queryItems = []
                }

                components?.queryItems?.append(.init(name: key, value: value))
            }

            var request = URLRequest(url: components!.url!)
            request.allHTTPHeaderFields = headers
            request.httpBody = try defaultEncoder.encode(body)
            request.httpMethod = method == .post ? "POST" : "GET"

//            print("  > \(request.httpMethod!) " + components!.url!.absoluteString)
//            print("  > \(headers)")
//            if let httpBody = request.httpBody {
//                print(String(data: httpBody, encoding: .utf8)!)
//            }
//            print("  > ")

            let (data, _) = try await client.data(for: request)

//            print("  < ")
//            print(String(data: data, encoding: .utf8)!)
//            print("  < ")

            return try defaultDecoder.decode(T.self, from: data)

        }

    static func execute<T: Decodable>(
        on client: URLSession,
        url: URL,
        headers: [String: String],
        parameters: [String: String],
        method: HTTPMethod = .get) async throws -> T {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

            for (key, value) in parameters {
                if components?.queryItems == nil {
                    components?.queryItems = []
                }
                components?.queryItems?.append(.init(name: key, value: value))
            }

            var request = URLRequest(url: components!.url!)
            request.allHTTPHeaderFields = headers
            request.httpMethod = method == .post ? "POST" : "GET"
//            print("  > \(request.httpMethod!) " + components!.url!.absoluteString)
//            print("  > \(headers)")
//            if let httpBody = request.httpBody {
//                print(String(data: httpBody, encoding: .utf8)!)
//            }
//            print("  > ")

            let (data, _) = try await client.data(for: request)

//            print("  < ")
//            print(String(data: data, encoding: .utf8)!)
//            print("  < ")

            return try defaultDecoder.decode(T.self, from: data)
        }

}
