// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import Credentials


func createUserProfile(from claims:AppleSignInClaims, details: AccountDetails?, for provider: String) -> UserProfile? {

    let userEmails = [UserProfile.UserProfileEmail(value: claims.email, type: "")]
    let displayName = details?.fullName ?? ""
    
    let name = UserProfile.UserProfileName(
        familyName: details?.lastName ?? "",
        givenName: details?.firstName ?? "",
        middleName: "")
    
    return UserProfile(id: claims.sub, displayName: displayName, provider: provider, name: name, emails: userEmails, photos: nil)
}
