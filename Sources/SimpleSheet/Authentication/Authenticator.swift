//
//  Authenticator.swift
//
//
//  Created by Adhiraj Singh on 5/10/20.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Abstract protocol that offers a way to provide a AccessToken
public protocol Authenticator {
    /**
     Authenticate & return an API key.
     For example, to authenticate for spreadsheet access, call ``` authenticate (scope: .sheets, client: someURLSession) ```

     - Parameter scope: the authentication scope for which you require an authentication key
     - Returns: a valid API key for the requested scope
     */
    func authenticate(scope: GoogleScope, client: URLSession) async throws -> AccessToken
}

extension Authenticator {
    /// Authenticate & return the authorisation header required to make an HTTP request
    public func authenticationHeader(scope: GoogleScope, client: URLSession) async throws -> (
        [String: String]
    ) {
        let token = try await authenticate(scope: scope, client: client)
        return ["access_token": token.accessToken]
    }
}

struct GoogleAuthenticationError: Error, Codable {
    let error: String
}

extension Decodable {

    public static func loading(fromJSONAt url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let obj = try decoder.decode(Self.self, from: data)
        return obj
    }

}
