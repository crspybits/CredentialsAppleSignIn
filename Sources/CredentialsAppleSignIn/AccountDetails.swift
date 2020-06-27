//
//  AccountDetails.swift
//  
//
//  Created by Christopher G Prince on 10/1/19.
//

// Because the JWT id token doesn't give the user's name. A JSON structure encoded from this can optionally be provided with the "X-account-details" header key.
// 6/26/20: I'm not getting email out of the JWT token now.

import Foundation

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
