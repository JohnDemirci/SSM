import XCTest
import Testing

struct IssueReporting {
    func fails() {
        let x = 5
        Issue.record("something")
    }
}

struct XCIssueReporting {
    func fails() {
        XCTFail("faulure message")
    }
}

final class IssueReprotingTests: XCTestCase {
    func testSample() {
        let rep = XCIssueReporting()
        let environment = ProcessInfo.processInfo.environment
        rep.fails()
    }
    
    func testUniversalIssueReporting() {
        let rep = IssueReporting()
        rep.fails()  // This should use XCTFail since we're in XCTest context
    }
}

// Swift Testing equivalent
@Suite("Issue Reporting Tests")
struct SwiftTestingIssueReportingTests {
    @Test("Universal issue reporting in Swift Testing")
    func testUniversalIssueReporting() {
        let rep = IssueReporting()
        let environment = ProcessInfo.processInfo.environment
        
        let displayname = Test.current?.name
        
        rep.fails()  // This should use Issue.record since we're in Swift Testing context
    }
}
