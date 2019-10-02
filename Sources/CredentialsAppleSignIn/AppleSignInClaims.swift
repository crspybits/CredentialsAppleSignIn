//
//  AppleSignInClaims.swift
//  CredentialsAppleSignIn
//
//  Created by Christopher G Prince on 9/12/19.
//

import Foundation
import SwiftJWT

// For these fields,
// See https://developer.apple.com/documentation/signinwithapplerestapi/authenticating_users_with_sign_in_with_apple

class AppleSignInClaims: Claims {
    // The issuer-registered claim key, which has the value https://appleid.apple.com.
    let iss: String
    
    // The unique identifier for the user.
    let sub: String
    
    // Your client_id in your Apple Developer account.
    let aud: String
    
    // The expiry time for the token. This value is typically set to 5 minutes.
    let exp: Date?
    
    // The time the token was issued.
    let iat: Date?
    
    // A String value used to associate a client session and an ID token. This value is used to mitigate replay attacks and is present only if passed during the authorization request.
    let nonce: String?
    
    // The user's email address.
    let email: String
    
    // A Boolean value that indicates whether the service has verified the email. The value of this claim is always true because the servers only return verified email addresses.
    let email_verified: String
}

extension AppleSignInClaims {
    /// Like the method in the JWT, but the leeway is intended: (a) only for the exp, and (b) is used to deal with the fact that Apple Sign In id tokens can't be created more than once every 24 hours.
    func validateClaims(leeway: TimeInterval = 0) -> ValidateClaimsResult {
        if let expirationDate = exp {
            if expirationDate + leeway < Date() {
                return .expired
            }
        }
        
        if let notBeforeDate = nbf {
            if notBeforeDate > Date() {
                return .notBefore
            }
        }
        
        if let issuedAtDate = iat {
            if issuedAtDate > Date() {
                return .issuedAt
            }
        }
        
        return .success
    }
}
