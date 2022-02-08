//
//  AuthenticationFactory.swift
//
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation

public protocol AccessTokenFactory {
    /// Fetches a fresh access token from Google
    func fetchToken(for scope: GoogleScope, client: URLSession) async throws -> AccessToken
}

public class AuthenticationFactory: Authenticator {
    public let scope: GoogleScope
    public let tokenFactory: AccessTokenFactory

    var token: AccessToken?
    let queue: DispatchQueue = .init(label: "serial-auth-factory", attributes: [])

    public init(scope: GoogleScope, using factory: AccessTokenFactory) {
        self.scope = scope
        self.tokenFactory = factory
    }
    
    func fetchToken(client: URLSession) async throws -> AccessToken {
        print("Renewing API key for \(self.scope)...")
        let token = try await tokenFactory.fetchToken(for: self.scope, client: client)
        return token.with(expiry: Date().addingTimeInterval(token.expiryDate.timeIntervalSince1970))
    }

    public func authenticate(scope: GoogleScope, client: URLSession) async throws -> AccessToken {
        if !scope.containsAny(scope) {
            throw GoogleAuthenticationError(error: "Cannot authenticate for given scope")
        }

        if token == nil {
            token = try await fetchToken(client: client)
        }

        return token!
    }
}
