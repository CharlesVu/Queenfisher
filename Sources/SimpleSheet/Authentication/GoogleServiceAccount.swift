//
//  GoogleServiceAccount.swift
//
//
//  Created by Adhiraj Singh on 5/16/20.
//

import Foundation
import JWTKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Google Service Account to use for authentication. See https://developers.google.com/identity/protocols/oauth2/service-account
public class GoogleServiceAccount: Codable, AccessTokenFactory {
    /// The JWT Claim
    struct Payload: JWTPayload {
        let iss: String
        let aud: URL
        let exp: ExpirationClaim
        let iat: Date
        let scope: GoogleScope

        func verify(using signer: JWTSigner) throws {
            try exp.verifyNotExpired()
        }
    }
    /// Access token returned for service accounts
    struct SAToken: Decodable {
        let accessToken: String
        let expiresIn: Double
        let tokenType: String
    }
    /// account type, ("service_account" in this class)
    public let type: String
    /// private key identifier
    public let privateKeyId: String
    /// private key data in a .pem format
    public let privateKey: String
    /// email of the service account
    public let clientEmail: String
    public let clientId: String
    public let clientX509CertUrl: URL
    /// URL to request authentication from
    public let tokenUri: URL

    public func factory(forScope scope: GoogleScope) -> AuthenticationFactory {
        .init(scope: scope, using: self)
    }
    public func fetchToken(for scope: GoogleScope, client: URLSession) async throws -> AccessToken {
        /*
         Structure of JWT & Claims from https://developers.google.com/identity/protocols/oauth2/service-account#authorizingrequests
         */
        let claim = Payload(
            iss: self.clientEmail,
            aud: self.tokenUri,
            exp: .init(value: Date(timeIntervalSinceNow: 60 * 60)),  // expire access token in 60 minutes
            iat: Date(),
            scope: scope)
        let signer = try JWTSigner.rs256(key: .private(pem: Data(self.privateKey.utf8)))  // signer using RS256, and our private key
        let signed = try signer.sign(claim)  // sign the token

        let body = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",  // Google requires this
            "assertion": signed,
        ]

        let token: SAToken = try await HTTPProxy.execute(on: client, url: tokenUri, headers: ["Content-Type": "application/json"], parameters: [:], body: body, method: .post)

        return AccessToken(
            accessToken: token.accessToken,
            tokenType: token.tokenType,
            scope: scope,
            refreshToken: nil,
            expiryDate: Date().addingTimeInterval(token.expiresIn))
    }
}
