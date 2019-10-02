//
//  File.swift
//  
//
//  Created by Christopher G Prince on 10/1/19.
//

// Because the JWT id token doesn't give the user's name. A JSON structure encoded from this can optional be provided with the "X-account-details" header key.

import Foundation

struct AccountDetails: Codable {
    let firstName: String?
    let lastName: String?
    let fullName: String?
}
