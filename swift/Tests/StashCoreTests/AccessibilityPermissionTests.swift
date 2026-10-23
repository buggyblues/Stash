import XCTest
@testable import StashUI

final class AccessibilityPermissionTests: XCTestCase {
    @MainActor func testDeniedPastesRequestSystemPermissionOnlyOncePerSession() async {
        let gate = AccessibilityPromptGate()
        var requests = 0
        for _ in 0..<5 {
            gate.requestIfNeeded(isTrusted: false) { requests += 1 }
        }
        XCTAssertEqual(requests, 1)
        // Returning from Settings without a valid grant must not start a loop.
        gate.requestIfNeeded(isTrusted: true) { requests += 1 }
        gate.requestIfNeeded(isTrusted: false) { requests += 1 }
        XCTAssertEqual(requests, 1)
    }

    @MainActor func testExistingGrantDoesNotPromptOrConsumeLaterPermissionRequest() async {
        let gate = AccessibilityPromptGate()
        var requests = 0
        gate.requestIfNeeded(isTrusted: true) { requests += 1 }
        XCTAssertEqual(requests, 0)
        gate.requestIfNeeded(isTrusted: false) { requests += 1 }
        XCTAssertEqual(requests, 1)
    }
}
