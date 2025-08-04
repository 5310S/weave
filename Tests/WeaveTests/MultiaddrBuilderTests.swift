import XCTest
@testable import weave

final class MultiaddrBuilderTests: XCTestCase {
    func testIPv6AddressBuildsCorrectMultiaddr() {
        let addr = multiaddrString(for: "2001:db8::1", port: 3030)
        XCTAssertEqual(addr, "/ip6/2001:db8::1/tcp/3030")
    }

    func testHostnameBuildsDNSMultiaddr() {
        let addr = multiaddrString(for: "example.com", port: 8080)
        XCTAssertEqual(addr, "/dns/example.com/tcp/8080")
    }
}
