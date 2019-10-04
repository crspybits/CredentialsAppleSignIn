# CredentialsAppleSignIn

A Kitura Credentials plugin for Apple Sign In, with a caveat.
I know of no really good way to validate the tokens provided by Apple Sign In, client-side on iOS, on the server.
See https://stackoverflow.com/questions/58178187/apple-sign-in-how-to-use-it-for-custom-server-endpoint-authentication

So, this is my best shot at it. It just validates an id token. Because the id tokens have expiry dates that officially timeout quickly, you get to specify your own custom `tokenExpiryValidationLeeway` in  the constructor:
```
CredentialsAppleSignInToken(clientId: String, tokenExpiryValidationLeeway: TimeInterval = 0, options: [String:Any]?=nil, tokenTimeToLive: TimeInterval? = nil)
```
I plan on using about 24 hours. In my server, I also plan to use a refresh token, and periodically use that to regenerate an id token. This will serve two purposes: 1) if the regeneration fails I'm going to fail the client-- presuming the refresh token has been revoked, and 2) if the regeneration works, I'm going to send the new id token back to the client, so the id token being sent to this plugin is less stale.

The `clientId` is as described here:
https://forums.developer.apple.com/thread/117210
https://developer.apple.com/documentation/signinwithapplejs/clientconfigi/3230948-clientid
https://developer.okta.com/blog/2019/06/04/what-the-heck-is-sign-in-with-apple

However-- the default for the clientId just seems to just be the reverse domain name style of your app id. For my demo app it is: com.SpasticMuffin.TestAppleSignIn

The `tokenTimeToLive` is as usual for Kitura Credentials plugins-- and indicates how long a token can be cached by this plugin after being validated.

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
struct AccountDetails: Codable {
    let firstName: String?
    let lastName: String?
    let fullName: String?
}
```

