//
//  ConnectionTesterTests.swift
//  MCPContxtTests
//
//  Tests for ConnectionTestResult properties and URL validation
//

import XCTest
@testable import MCPContxt

final class ConnectionTesterTests: XCTestCase {

    // MARK: - ConnectionTestResult properties

    func testSuccessIsReachable() {
        let result = ConnectionTestResult.success
        XCTAssertTrue(result.isReachable)
        XCTAssertFalse(result.isAuthRequired)
    }

    func testAuthRequiredIsReachable() {
        let result = ConnectionTestResult.authRequired
        XCTAssertTrue(result.isReachable)
        XCTAssertTrue(result.isAuthRequired)
    }

    func testUnreachableIsNotReachable() {
        let result = ConnectionTestResult.unreachable("timeout")
        XCTAssertFalse(result.isReachable)
        XCTAssertFalse(result.isAuthRequired)
    }

    func testInvalidURLIsNotReachable() {
        let result = ConnectionTestResult.invalidURL
        XCTAssertFalse(result.isReachable)
        XCTAssertFalse(result.isAuthRequired)
    }

    // MARK: - URL validation via test()

    func testInvalidURLReturnsInvalidURL() async {
        let result = await ConnectionTester.test(url: "not a url %%%", headers: nil)
        if case .invalidURL = result {
            // expected
        } else {
            XCTFail("Expected .invalidURL, got \(result)")
        }
    }

    func testEmptyURLReturnsInvalidURL() async {
        let result = await ConnectionTester.test(url: "", headers: nil)
        if case .invalidURL = result {
            // expected
        } else {
            XCTFail("Expected .invalidURL, got \(result)")
        }
    }

    // MARK: - testCommand validation

    func testEmptyCommandReturnsInvalidURL() async {
        let result = await ConnectionTester.testCommand("")
        if case .invalidURL = result {
            // expected
        } else {
            XCTFail("Expected .invalidURL, got \(result)")
        }
    }

    func testNonexistentCommandReturnsUnreachable() async {
        let result = await ConnectionTester.testCommand("definitely_not_a_real_command_12345")
        if case .unreachable = result {
            // expected
        } else {
            XCTFail("Expected .unreachable, got \(result)")
        }
    }
}
