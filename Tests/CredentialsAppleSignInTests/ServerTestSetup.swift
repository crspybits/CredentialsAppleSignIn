//
//  ServerTestSetup.swift
//  CredentialsAppleSignInTests
//
//  Created by Christopher G Prince on 9/8/19.
//

// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle/blob/master/Tests/CredentialsGoogleTests/CredentialsGoogleTests.swift

import XCTest
import Kitura
import KituraNet
import Foundation
import Dispatch

protocol ServerTestSetup {
    func expectation(_ index: Int) -> XCTestExpectation
    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?)
}

extension ServerTestSetup {

    func doTearDown() {
        //       sleep(10)
    }

    func performServerTest(router: ServerDelegate, asyncTasks: (XCTestExpectation) -> Void...) {
        do {
            let server = try HTTPServer.listen(on: 8090, delegate: router)
            let requestQueue = DispatchQueue(label: "Request queue")

            for (index, asyncTask) in asyncTasks.enumerated() {
                let expectation = self.expectation(index)
                requestQueue.sync {
                    asyncTask(expectation)
                }
            }

            waitExpectation(timeout: 10) { error in
                // blocks test until request completes
                server.stop()
                XCTAssertNil(error);
            }
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func performRequest(method: String, host: String = "localhost", path: String, headers: [String: String]? = nil, callback: @escaping ClientRequest.Callback, requestModifier: ((ClientRequest) -> Void)? = nil) {
        var allHeaders = [String: String]()
        if  let headers = headers  {
            for  (headerName, headerValue) in headers  {
                allHeaders[headerName] = headerValue
            }
        }
        allHeaders["Content-Type"] = "text/plain"
        let options: [ClientRequest.Options] =
                [.method(method), .hostname(host), .port(8090), .path(path), .headers(allHeaders)]
        let req = HTTP.request(options, callback: callback)
        if let requestModifier = requestModifier {
            requestModifier(req)
        }
        req.end()
    }
}

extension XCTestCase: ServerTestSetup {
    func expectation(_ index: Int) -> XCTestExpectation {
        let expectationDescription = "\(type(of: self))-\(index)"
        return self.expectation(description: expectationDescription)
    }

    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?) {
        self.waitForExpectations(timeout: t, handler: handler)
    }
}
