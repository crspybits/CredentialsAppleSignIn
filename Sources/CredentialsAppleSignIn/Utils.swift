// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import Credentials


func createUserProfile(from claims:AppleSignInClaims, details: AccountDetails?, for provider: String) -> UserProfile? {

    let userEmails = [UserProfile.UserProfileEmail(value: claims.email, type: "")]
    let displayName = details?.fullName ?? ""
    
    return UserProfile(id: claims.sub, displayName: displayName, provider: provider, name: nil, emails: userEmails, photos: nil)
}
