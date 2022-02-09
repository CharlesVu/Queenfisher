//
//  File.swift
//
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation

let oAuthApiUrl = URL(string: "https://oauth2.googleapis.com/token")!

public struct GoogleOAuthClient: Codable, AccessTokenFactory {
    public struct Content: Codable {
        public var clientId: String
        public var clientSecret: String
        public var redirectUris: [URL]
        public var authUri: URL
    }
    public let web: Content
    private var factoryToken: AccessToken?

    public func authUrl(for scope: GoogleScope, loginHint: String? = nil) -> URL {
        var comps = URLComponents(url: web.authUri, resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = []
        query.append(.init(name: "client_id", value: web.clientId))
        query.append(.init(name: "scope", value: scope.rawValue))
        query.append(.init(name: "access_type", value: AccessType.offline.rawValue))
        query.append(.init(name: "response_type", value: ResponseType.code.rawValue))
        query.append(.init(name: "redirect_uri", value: web.redirectUris.first!.absoluteString))
        if let hint = loginHint {
            query.append(.init(name: "login_hint", value: hint))
        }
        comps.queryItems = query
        return comps.url!
    }
    public func fetchToken(fromCode code: String, client: URLSession) async throws -> AccessToken {
        let req: OAuthRequest = .init(
            code: code,
            refreshToken: nil,
            clientId: web.clientId,
            clientSecret: web.clientSecret,
            redirectUri: web.redirectUris.first!,
            grantType: .authorizationCode)

        let token: AccessToken = try await HTTPProxy.execute(on: client, url: oAuthApiUrl, headers: [:], parameters: [:], body: req, method: .post)

        return token.with(expiry: Date().addingTimeInterval(token.expiryDate.timeIntervalSince1970))
    }

    public func fetchToken(for scope: GoogleScope, client: URLSession) async throws -> AccessToken {
        guard let factoryKeyToken = self.factoryToken?.refreshToken else {
            throw GoogleAuthenticationError.init(error: "refresh token absent")
        }
        let req: OAuthRequest = .init(
            code: nil,
            refreshToken: factoryKeyToken,
            clientId: self.web.clientId,
            clientSecret: self.web.clientSecret,
            redirectUri: self.web.redirectUris.first!,
            grantType: .refreshToken)
        return try await HTTPProxy.execute(on: client, url: oAuthApiUrl, headers:[:], parameters: [:], body: req, method: .post)
    }

    public func factory(usingAccessToken token: AccessToken) throws -> AuthenticationFactory {
        guard let _ = token.refreshToken else {
            throw GoogleAuthenticationError(error: "refresh token absent")
        }
        var oauth = self
        oauth.factoryToken = token
        return .init(scope: token.scope, using: oauth)
    }

    struct OAuthRequest: Codable {
        let code: String?
        let refreshToken: String?
        let clientId: String
        let clientSecret: String
        let redirectUri: URL
        let grantType: GrantType
    }
    public enum GrantType: String, Codable {
        case authorizationCode = "authorization_code"
        case refreshToken = "refresh_token"
    }
    public enum ResponseType: String, Codable {
        case code = "code"
    }
    public enum AccessType: String, Codable {
        case offline = "offline"
        case online = "online"
    }
}
