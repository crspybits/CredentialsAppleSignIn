// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import Credentials
import Foundation
import HeliumLogger
import LoggerAPI

/// extendedProperties in the UserProfile will have the key `appleSignInTokenExpiryKey`
/// with a Date value-- indicating when the token expires/expired.
public let appleSignInTokenExpiryKey = "appleSignInTokenExpiry"

/// Attempts to get the email first from claims, and then from the details.
func createUserProfile(from claims:AppleSignInClaims, details: AccountDetails?, for provider: String, appleSignInTokenExpiry: Date) -> UserProfile? {

    let email = claims.email ?? details?.email ?? ""

    let userEmails = [UserProfile.UserProfileEmail(value: email, type: "")]
    let displayName = details?.fullName ?? ""
    
    let name = UserProfile.UserProfileName(
        familyName: details?.lastName ?? "",
        givenName: details?.firstName ?? "",
        middleName: "")
        
    Log.debug("CredentialsAppleSignIn: createUserProfile: Email: \(email); displayName: \(displayName); lastName: \(String(describing: details?.lastName)); firstName: \(String(describing: details?.firstName))")
    
    return UserProfile(id: claims.sub, displayName: displayName, provider: provider, name: name, emails: userEmails, photos: nil, extendedProperties: [appleSignInTokenExpiryKey: appleSignInTokenExpiry])
}
