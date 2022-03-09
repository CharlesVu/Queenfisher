//
//  AccessToken.swift
//
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AccessToken: Codable, Authenticator {
    public var accessToken: String
    /// HTTP token type: bearer, basic etc.
    public let tokenType: String
    /// Scope for which the key is valid
    public let scope: GoogleScope
    /// Refresh token
    public let refreshToken: String?
    /// Date after which the token will be invalid
    internal(set) public var expiryDate: Date

    /// Check if the API Key has expired
    public var isExpired: Bool {
        Date().timeIntervalSince(expiryDate) > 0
    }

    public func authenticate(
        scope: GoogleScope,
        client: URLSession
    ) async throws -> AccessToken {
        if self.isExpired {
            throw GoogleAuthenticationError(error: "token expired")
        } else if !self.scope.containsAny(scope) {
            throw GoogleAuthenticationError(error: "invalid scope")
        } else {
            return self
        }
    }

    func with(expiry date: Date) -> AccessToken {
        .init(
            accessToken: accessToken,
            tokenType: tokenType,
            scope: scope,
            refreshToken: refreshToken,
            expiryDate: date)
    }
}
