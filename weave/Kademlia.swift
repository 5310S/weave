import Foundation

/// A very small and naive representation of a Kademlia-style
/// distributed hash table (DHT) node. It is *not* a full
/// implementation of the protocol but demonstrates the basic
/// idea of storing and locating values by key using XOR distance.
public final class KademliaNode {
    public let id: UInt64
    private var peers: [KademliaNode] = []
    private var store: [UInt64: String] = [:]

    public init(id: UInt64 = UInt64.random(in: 0..<UInt64.max)) {
        self.id = id
    }

    /// Join the network by adding a bootstrap peer. In a full
    /// implementation this would trigger bucket population and
    /// key lookups but here it merely stores the reference.
    public func join(bootstrap: KademliaNode) {
        if !peers.contains(where: { $0 === bootstrap }) {
            peers.append(bootstrap)
        }
    }

    /// Store a value locally associated with the provided key.
    /// In real Kademlia this would replicate to k closest nodes.
    public func store(value: String, for key: UInt64) {
        store[key] = value
    }

    /// Attempt to find a value for the given key. If not stored
    /// locally, the query is forwarded to the known peer whose
    /// ID is closest to the key according to XOR distance.
    public func findValue(for key: UInt64) -> String? {
        if let value = store[key] {
            return value
        }
        guard let closest = peers.min(by: { ($0.id ^ key) < ($1.id ^ key) }) else {
            return nil
        }
        return closest.findValue(for: key)
    }
}
