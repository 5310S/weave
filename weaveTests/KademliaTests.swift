import Testing
@testable import weave

struct KademliaTests {
    /// Storing a value on a bootstrap node should allow a joined
    /// node to retrieve it via the simplistic lookup mechanism.
    @Test func storeAndLookup() async throws {
        let bootstrap = KademliaNode(id: 1)
        let node = KademliaNode(id: 2)
        node.join(bootstrap: bootstrap)

        let key: UInt64 = 42
        bootstrap.store(value: "hello", for: key)

        let result = node.findValue(for: key)
        #expect(result == "hello")
    }
}
