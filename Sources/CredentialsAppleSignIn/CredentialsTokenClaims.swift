//
//  CredentialsTokenClaims.swift
//  CredentialsAppleSignIn
//
//  Created by Christopher G Prince on 9/12/19.
//

import Foundation
import AppleJWTDecoder
import HeliumLogger
import LoggerAPI

// For these fields,
// See https://developer.apple.com/documentation/signinwithapplerestapi/authenticating_users_with_sign_in_with_apple

class CredentialsTokenClaims: AppleClaims {
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
    let email: String?
    
    // A Boolean value that indicates whether the service has verified the email. The value of this claim is always true because the servers only return verified email addresses.
    let email_verified: String?

    func validateClaims() -> Bool {
        let leeway: TimeInterval = 120
        let today = Date()
        
        if let notBeforeDate = nbf {
            if notBeforeDate > today + leeway {
                Log.error("notBeforeDate: \(notBeforeDate) > today: \(today)")
                return false
            }
        }
        
        if let issuedAtDate = iat {
            if issuedAtDate > today + leeway {
                Log.error("issuedAtDate: \(issuedAtDate) > today: \(today)")
                return false
            }
        }
        
        return true
    }
}

