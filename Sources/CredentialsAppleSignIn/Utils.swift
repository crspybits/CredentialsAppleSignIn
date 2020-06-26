// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import Credentials
import Foundation

/// extendedProperties in the UserProfile will have the key `appleSignInTokenExpiryKey`
/// with a Date value-- indicating when the token expires/expired.
public let appleSignInTokenExpiryKey = "appleSignInTokenExpiry"

func createUserProfile(from claims:AppleSignInClaims, details: AccountDetails?, for provider: String, appleSignInTokenExpiry: Date) -> UserProfile? {

    let userEmails = [UserProfile.UserProfileEmail(value: claims.email, type: "")]
    let displayName = details?.fullName ?? ""
    
    let name = UserProfile.UserProfileName(
        familyName: details?.lastName ?? "",
        givenName: details?.firstName ?? "",
        middleName: "")
    
    return UserProfile(id: claims.sub, displayName: displayName, provider: provider, name: name, emails: userEmails, photos: nil, extendedProperties: [appleSignInTokenExpiryKey: appleSignInTokenExpiry])
}
