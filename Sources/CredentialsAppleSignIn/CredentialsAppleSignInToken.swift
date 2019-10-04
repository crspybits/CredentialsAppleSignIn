// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import Kitura
import KituraNet
import LoggerAPI
import Credentials
import HeliumLogger
import Foundation
import LoggerAPI

/// Protocol to make it easier to add token TLL to credentials plugins.
public protocol CredentialsTokenTLL {
    var usersCache: NSCache<NSString, BaseCacheElement>? {get}
    var tokenTimeToLive: TimeInterval? {get}
}

extension CredentialsTokenTLL {
    /// Returns true iff the token/UserProfile was found in the cache and onSuccess was called.
    ///
    /// - Parameter token: The Oauth2 token, used as a key in the cache.
    /// - Parameter onSuccess: The callback used in the authenticate method.
    ///
    func useTokenInCache(token: String, onSuccess: @escaping (UserProfile) -> Void) -> Bool {
        #if os(Linux)
            let key = NSString(string: token)
        #else
            let key = token as NSString
        #endif
        
        if let cached = usersCache?.object(forKey: key) {
            if let ttl = tokenTimeToLive {
                if Date() < cached.createdAt.addingTimeInterval(ttl) {
                    onSuccess(cached.userProfile)
                    return true
                }
                // If current time is later than time to live, continue to standard token authentication.
                // Don't need to evict token, since it will replaced if the token is successfully autheticated.
            } else {
                // No time to live set, use token until it is evicted from the cache
                onSuccess(cached.userProfile)
                return true
            }
        }
        
        return false
    }
}

/// Authentication using Apple Sign In OAuth2 token.
public class CredentialsAppleSignInToken: CredentialsPluginProtocol, CredentialsTokenTLL {
    /// The name of the plugin.
    public var name: String {
        return "AppleSignInToken"
    }
    
    /// An indication as to whether the plugin is redirecting or not.
    public var redirecting: Bool {
        return false
    }
    
    /// The time in seconds since the user profile was generated that the access token will be considered valid.
    public let tokenTimeToLive: TimeInterval?
    
    private let clientId: String
    private let tokenExpiryValidationLeeway: TimeInterval

    private var delegate: UserProfileDelegate?
    private var accountDetails: AccountDetails?
    private let decoder = JSONDecoder()
    
    /// A delegate for `UserProfile` manipulation.
    public var userProfileDelegate: UserProfileDelegate? {
        return delegate
    }
    
    /// Initialize a `CredentialsAppleSignInToken` instance.
    ///
    /// - Parameter clientId: The developer's Apple client_id -- used in Oauth token verification.
    /// - Parameter options: A dictionary of plugin specific options. The keys are defined in `CredentialsAppleSignInOptions`.
    /// - Parameter tokenTimeToLive: The time in seconds since the user profile was generated that the access token will be considered valid.
    public init(clientId: String, tokenExpiryValidationLeeway: TimeInterval = 0, options: [String:Any]?=nil, tokenTimeToLive: TimeInterval? = nil) {
        delegate = options?[CredentialsAppleSignInOptions.userProfileDelegate] as? UserProfileDelegate
        self.tokenTimeToLive = tokenTimeToLive
        self.clientId = clientId
        self.tokenExpiryValidationLeeway = tokenExpiryValidationLeeway
    }
    
    /// User profile cache.
    public var usersCache: NSCache<NSString, BaseCacheElement>?
    
    private let tokenTypeKey = "X-token-type"
    private let accessTokenKey = "access_token"
    
    // Optional HTTP header key; contents
    private let accountDetailsKey = "X-account-details"

    
    /// Authenticate incoming request using Apple Sign In OAuth2 token.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onPass: The closure to invoke when the plugin doesn't recognize the
    ///                     authentication token in the request.
    /// - Parameter inProgress: The closure to invoke to cause a redirect to the login page in the
    ///                     case of redirecting authentication.
    public func authenticate(request: RouterRequest, response: RouterResponse,
                             options: [String:Any], onSuccess: @escaping (UserProfile) -> Void,
                             onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                             onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                             inProgress: @escaping () -> Void) {

        guard let type = request.headers[tokenTypeKey], type == name else {
            onPass(nil, nil)
            return
        }
        
        guard let accessToken = request.headers[accessTokenKey] else {
            onFailure(nil, nil)
            return
        }
        
        if useTokenInCache(token: accessToken, onSuccess: onSuccess) {
            return
        }
        
        if let details = request.headers[accountDetailsKey],
            let detailsData = details.data(using: .utf8) {
            
            do {
                accountDetails = try decoder.decode(AccountDetails.self, from: detailsData)
            } catch let error {
                Log.error("Could not decode Account Details: \(error)")
            }
        }
        
        doRequest(token: accessToken, options: options, onSuccess: onSuccess, onFailure: { _ in
            onFailure(nil, nil)
        })
    }
    
    enum FailureResult: Swift.Error {
        case badResponse
        case statusCode(HTTPStatusCode)
        case failedSerialization
        case failedCreatingProfile
        case failedGettingBodyData
        case failedDecodingPublicKey
        case failedVerifyingToken
        case failedGettingSelf
    }
    
    // Fetch
    func doRequest(token: String, options: [String:Any],
        onSuccess: @escaping (UserProfile) -> Void,
        onFailure: @escaping (Swift.Error) -> Void) {
        
        // Get Apple's public key to validate the token
        // https://developer.apple.com/documentation/signinwithapplerestapi/fetch_apple_s_public_key_for_verifying_token_signature

        var requestOptions: [ClientRequest.Options] = []
        requestOptions.append(.schema("https://"))
        requestOptions.append(.hostname("appleid.apple.com"))
        requestOptions.append(.method("GET"))
        requestOptions.append(.path("/auth/keys"))

        let req = HTTP.request(requestOptions) {[weak self] response in
            guard let self = self else {
                onFailure(FailureResult.failedGettingSelf)
                return
            }
            
            guard let response = response else {
                onFailure(FailureResult.badResponse)
                return
            }
            
            guard response.statusCode == HTTPStatusCode.OK else {
                onFailure(FailureResult.statusCode(response.statusCode))
                return
            }
            
            var body = Data()
            do {
                try response.readAllData(into: &body)
            } catch let error {
                Log.debug("\(error)")
                onFailure(FailureResult.failedGettingBodyData)
                return
            }

            let applePublicKey:ApplePublicKey
            
            do {
                applePublicKey = try self.decoder.decode(ApplePublicKey.self, from: body)
            } catch let error {
                Log.error("Failed to decode public key: \(error)")
                onFailure(FailureResult.failedDecodingPublicKey)
                return
            }
            
            let tokenVerificationResult = applePublicKey.verifyToken(token, clientId: self.clientId, expiryLeeway: self.tokenExpiryValidationLeeway)
            guard case .success(let claims) = tokenVerificationResult else {
                Log.error("Failed token verification: \(tokenVerificationResult)")
                onFailure(FailureResult.failedVerifyingToken)
                return
            }
            
            guard let userProfile = createUserProfile(from: claims, details: self.accountDetails, for: self.name) else {
                Log.error("Failed to create user profile")
                onFailure(FailureResult.failedCreatingProfile)
                return
            }
            
            if let delegate = self.delegate ?? options[CredentialsAppleSignInOptions.userProfileDelegate] as? UserProfileDelegate {
                delegate.update(userProfile: userProfile, from: [:])
            }
            
            let newCacheElement = BaseCacheElement(profile: userProfile)
            #if os(Linux)
                let key = NSString(string: token)
            #else
                let key = token as NSString
            #endif
            
            self.usersCache!.setObject(newCacheElement, forKey: key)
            onSuccess(userProfile)
        }
        
        // print("URL: " + req.url)
        req.end()
    }
}
