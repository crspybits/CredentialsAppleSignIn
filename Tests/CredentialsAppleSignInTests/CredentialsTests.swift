//
//  CredentialsTests.swift
//  
//
//  Created by Christopher G Prince on 9/29/19.
//

import XCTest
@testable import CredentialsAppleSignIn
import Kitura
import KituraNet
import Credentials
import KituraSession
import SwiftJWT

struct AppleSignInPlist: Decodable {
    let idToken: String // the Oauth2 JWT from Apple Sign In
    
    // Developer's Apple client_id
    let clientId: String
    
    // This needs to be the same as the email contained in the email field inside of the idToken-- i.e., the sign in email used with Apple Sign In
    let email: String
    
    // This needs to be the same as the sub field contained inside of the idToken-- i.e., the user identifier used with Apple Sign In
    let sub: String
}

final class CredentialsTests: XCTestCase {
    var router:Router!
    let credentials = Credentials()
    var appleCredentials:CredentialsAppleSignInToken!
    let tokenTypeKey = "X-token-type"
    let accessTokenKey = "access_token"
    let authTokenType = "AppleSignInToken"
    let accountDetailsKey = "X-account-details"
    let plist: AppleSignInPlist = CredentialsTests.getPlist()
    
    static func getPlist() -> AppleSignInPlist {
        // I know this is gross. Swift packages just don't have a good way to access resources right now.
        // See https://stackoverflow.com/questions/47177036
        let url = URL(fileURLWithPath: "/Users/chris/Desktop/Apps/SyncServerII/Private/CredentialsAppleSignIn/token.plist")
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not get data from url")
        }

        let decoder = PropertyListDecoder()

        guard let plist = try? decoder.decode(AppleSignInPlist.self, from: data) else {
            fatalError("Could not decode the plist")
        }

        return plist
    }
    
    override func setUp() {
        super.setUp()
        appleCredentials = CredentialsAppleSignInToken(clientId: plist.clientId)
        router = setupRouter()
    }
    
    func setupRouter() -> Router {
        let router = Router()
        
        router.all(middleware: KituraSession.Session(secret: "foobar"))
        credentials.register(plugin: appleCredentials)
        
        router.all { (request, response, next) in
            self.credentials.handle(request: request, response: response, next: next)
        }
        
        router.get("handler") { (request, response, next) in
            response.send("Done!")
        }

        return router
    }
    
    func testRequestFailsWithNoAuthHeader() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/handler", callback: { response in
                guard response?.httpStatusCode == .unauthorized else {
                    XCTFail("response?.httpStatusCode.rawValue: \(String(describing: response?.httpStatusCode.rawValue))")
                    expectation.fulfill()
                    return
                }
                expectation.fulfill()
            })
        }
    }
    
    func testRequestFailsWithBadAuthHeader() {
        let headers: [String: String] = [
            accessTokenKey: "foo",
            tokenTypeKey: authTokenType
        ]
        
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/handler", headers: headers, callback: { response in
                guard response?.httpStatusCode == .unauthorized else {
                    XCTFail("response?.httpStatusCode.rawValue: \(String(describing: response?.httpStatusCode.rawValue))")
                    expectation.fulfill()
                    return
                }
                expectation.fulfill()
            })
        }
    }
    
    func testRequestSucceedsWithValidAuthHeader() {
        let headers: [String: String] = [
            accessTokenKey: plist.idToken,
            tokenTypeKey: authTokenType
        ]
        
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/handler", headers: headers, callback: { response in
                guard response?.httpStatusCode == .OK else {
                    XCTFail("response?.httpStatusCode.rawValue: \(String(describing: response?.httpStatusCode.rawValue))")
                    expectation.fulfill()
                    return
                }
                expectation.fulfill()
            })
        }
    }
    
    func testRequestSucceedsWithValidAuthHeaderAndAccountDetails() {
        let accountDetails = AccountDetails(firstName: "Christopher", lastName: "Prince", fullName: "Christopher Prince")
        let encoder = JSONEncoder()
        guard let accountDetailsData = try? encoder.encode(accountDetails),
            let accountDetailsString = String(data: accountDetailsData, encoding: .utf8) else {
            XCTFail()
            return
        }
        
        let headers: [String: String] = [
            accessTokenKey: plist.idToken,
            tokenTypeKey: authTokenType,
            
            // This is optional.
            accountDetailsKey: accountDetailsString
        ]
        
        XCTAssert(appleCredentials.usersCache?.object(forKey: plist.idToken as NSString) == nil)
        
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/handler", headers: headers, callback: { response in
                guard response?.httpStatusCode == .OK else {
                    XCTFail("response?.httpStatusCode.rawValue: \(String(describing: response?.httpStatusCode.rawValue))")
                    expectation.fulfill()
                    return
                }
                
                guard let profile = self.appleCredentials.usersCache?.object(forKey: self.plist.idToken as NSString) else {
                    XCTFail()
                    expectation.fulfill()
                    return
                }
                
                XCTAssert(profile.userProfile.displayName == accountDetails.fullName)
                XCTAssert(profile.userProfile.name?.familyName == accountDetails.lastName)
                XCTAssert(profile.userProfile.name?.givenName == accountDetails.firstName)
                
                guard let emails = profile.userProfile.emails,
                    emails.count == 1 else {
                    XCTFail()
                    expectation.fulfill()
                    return
                }
                
                let email = emails[0]
                XCTAssert(email.value == self.plist.email)
                
                XCTAssert(profile.userProfile.id == self.plist.sub)

                expectation.fulfill()
            })
        }
    }
}

