import Foundation
import Testing
@testable import CoWrittenMac

@Test func credentialsAreBoundToCanonicalHTTPSOrigin() throws {
    #expect(try AIClient.tokenAccount(" https://Example.COM/ ") == "https://example.com/v1/analyze")
    #expect(try AIClient.endpoint("https://example.com:8443").absoluteString == "https://example.com:8443/v1/analyze")
}
@Test func rejectInsecureOrAmbiguousDestinations() {
    for bad in ["http://example.com", "https://user:password@example.com", "https://example.com/api", "https://example.com?token=secret", "https://example.com#other", "file:///tmp/server", "", "example.com"] {
        #expect(throws: AIClientError.self) { try AIClient.endpoint(bad) }
    }
}
