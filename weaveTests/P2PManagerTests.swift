import Testing
@testable import weave

struct P2PManagerTests {
    @Test func listenerStarts() async throws {
        let manager = P2PManager()
        manager.startListening(on: 9999)
        // Wait briefly to allow listener to start
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(manager.isListening)
    }
}
