// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import Kitura
import KituraNet
import LoggerAPI
import Credentials
import HeliumLogger
import Foundation
import LoggerAPI
import AppleJWTDecoder

public let tokenType = "AppleSignInToken"

/// Authentication using Apple Sign In OAuth2 token.
public class CredentialsAppleSignInToken: CredentialsPluginProtocol, CredentialsTokenTTL {
    /// The name of the plugin.
    public var name: String {
        return tokenType
    }
    
    /// An indication as to whether the plugin is redirecting or not.
    public var redirecting: Bool {
        return false
    }
    
    /// The time in seconds since the user profile was generated that the access token will be considered valid.
    public let tokenTimeToLive: TimeInterval?
    
    private let clientId: String

    private var delegate: UserProfileDelegate?
    private var accountDetails: AccountDetails?
    private let decoder = JSONDecoder()
    
    /// A delegate for `UserProfile` manipulation.
    public var userProfileDelegate: UserProfileDelegate? {
        return delegate
    }
    
    /// Initialize a `CredentialsAppleSignInToken` instance.
    ///
    /// - Parameter clientId: The developer's Apple client_id -- used in Oauth token verification. e.g., com.foobar.appName
    /// - Parameter options: A dictionary of plugin specific options. The keys are defined in `CredentialsAppleSignInOptions`.
    public init(clientId: String, options: [String:Any]?=nil, tokenTimeToLive: TimeInterval? = nil) {
        delegate = options?[CredentialsAppleSignInOptions.userProfileDelegate] as? UserProfileDelegate
        self.tokenTimeToLive = tokenTimeToLive
        self.clientId = clientId
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
                
        if let details = request.headers[self.accountDetailsKey],
            let detailsData = details.data(using: .utf8) {
            
            do {
                self.accountDetails = try self.decoder.decode(AccountDetails.self, from: detailsData)
            } catch let error {
                Log.error("Could not decode Account Details: \(error)")
            }
        }
        
        getProfileAndCacheIfNeeded(token: accessToken, options: options, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    enum CredentialsAppleSignInTokenError: Swift.Error {
        case failedCreatingProfile
        case failedVerifyingToken
        case noExpiryInClaims
        case failureResult(FailureResult)
    }
    
    // Validate the id token provided by the user-- to the extent we can (without checking its expiry).
    public func generateNewProfile(token: String, options: [String:Any], completion: @escaping (CredentialsTokenTTLResult) -> Void) {
    
        ApplePublicKey.httpFetch { (result: Swift.Result<ApplePublicKey<CredentialsTokenClaims>, FailureResult>) in
            let applePublicKey:ApplePublicKey<CredentialsTokenClaims>
            switch result {
            case .success(let key):
                applePublicKey = key
                
            case .failure(let failure):
                completion(.error(CredentialsAppleSignInTokenError.failureResult(failure)))
                return
            }
            
            let verifyResult = applePublicKey.verifyToken(token, clientId: self.clientId)
            let tokenClaims: CredentialsTokenClaims
            switch verifyResult {
            case .success(let claims):
                Log.info("claims: \(claims)")
                tokenClaims = claims
            default:
                Log.error("Failed token verification: \(verifyResult)")
                completion(.error(CredentialsAppleSignInTokenError.failedVerifyingToken))
                return
            }
            
            guard let expiry = tokenClaims.exp else {
                Log.error("No expiry in claims!")
                completion(.error(CredentialsAppleSignInTokenError.noExpiryInClaims))
                return
            }
            
            Log.debug("expiry: \(expiry); issue time: \(String(describing: tokenClaims.iat))")
            
            guard let userProfile = createUserProfile(from: tokenClaims, details: self.accountDetails, for: self.name, appleSignInTokenExpiry: expiry) else {
                Log.error("Failed to create user profile")
                completion(.error(CredentialsAppleSignInTokenError.failedCreatingProfile))
                return
            }
            
            if let delegate = self.delegate ?? options[CredentialsAppleSignInOptions.userProfileDelegate] as? UserProfileDelegate {
                delegate.update(userProfile: userProfile, from: [:])
            }
            
            completion(.success(userProfile))
        }
    }
}
