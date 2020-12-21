# CredentialsAppleSignIn

A Kitura Credentials plugin for Apple Sign In that operates in a somewhat non-standard way -- relative to other Kitura Credentials plugins. Other Kitura Credentials plugins that I've seen consider credentials to be valid only if they can, with certainty, determine if the credentials are valid. [The identity token with Apple Sign In, however, cannot always be checked in this manner](https://medium.com/@crspybits/part-ii-apple-sign-in-custom-servers-and-an-expiry-conundrum-b3e9735dc079#45ed-bcd64527751a).

Instead, the result of processing with this Apple Sign In Kitura Credentials plugin has three states:
1) The plugin fails to authenticate the user — e.g., if an invalid identity token is given to the plugin;
2) The plugin authenticates the user, and the expiry date in the token is still valid: Probably this is the only resulting state in which you'll want to create a new user downstream of the plugin — on your custom server.
3) The plugin authenticates the user, and the expiry date in the token is no longer valid: This is the ongoing typical state because the id token, when issued, has an expiry date that is valid only for a brief period (five minutes).

Parameters for the `CredentialsAppleSignInToken` constructor:

`clientId` is as described here:
https://forums.developer.apple.com/thread/117210
https://developer.apple.com/documentation/signinwithapplejs/clientconfigi/3230948-clientid
https://developer.okta.com/blog/2019/06/04/what-the-heck-is-sign-in-with-apple

However-- the default for the clientId just seems to just be the reverse domain name style of your app id. For my demo app it is: com.SpasticMuffin.TestAppleSignIn

The `tokenTimeToLive` (optional) is as usual for Kitura Credentials plugins-- and indicates how long a id token can be cached by this plugin after being validated.

HTTP clients connecting to the server using this Credentials plugin must give the following two header keys:

```
    let tokenTypeKey = "X-token-type"
    let accessTokenKey = "access_token"
```
The `tokenTypeKey` must have the value "AppleSignInToken"
The `accessTokenKey` must have your Apple Sign In id token.

Optionally, you can also provide the header key:
```
    let accountDetailsKey = "X-account-details"
```
Its value must be a string, the JSON encoding of the AccountDetails struct:
```
    public struct AccountDetails: Codable {
        public let firstName: String?
        public let lastName: String?
        public let fullName: String?
        public let email: String?
        
        init(firstName: String? = nil, lastName: String? = nil, fullName: String? = nil, email: String? = nil) {
            self.firstName = firstName
            self.lastName = lastName
            self.fullName = fullName
            self.email = email
        }
    }
```

In order to support the two "success" outcomes of processing using this plugin, the `extendedProperties` of the `UserProfile` has the following key:
```
    /// extendedProperties in the UserProfile will have the key `appleSignInTokenExpiryKey`
    /// with a Date value-- indicating when the token expires/expired.
    public let appleSignInTokenExpiryKey = "appleSignInTokenExpiry"
```

`UserProfile` objects, as usual for Kitura Credentials, are obtained from the credentials cache, keyed by access token (id token in the case of Apple Sign In). For example:
```
    guard let cache = self.appleCredentials.usersCache?.object(forKey: self.idToken as NSString) else {
        // You need to handle error
        return
    }

    guard let expiry = cache.userProfile.extendedProperties[CredentialsAppleSignIn.appleSignInTokenExpiryKey] as? Date else {
        // You need to handle error
        return
    }
    
    if expiry > Date() {
        // identity token hasn't expired-- e.g., you could create an account for the user in this state
    }
    else {
        // identity token has expired-- and will need further downstream checking. For example, see Mechanism 2 in https://medium.com/@crspybits/part-ii-apple-sign-in-custom-servers-and-an-expiry-conundrum-b3e9735dc079#45ed-bcd64527751as
    }
```


