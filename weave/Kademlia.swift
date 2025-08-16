import Foundation
import Network


/// A more complete Kademlia distributed hash table implementation suitable for
/// experimentation.  It supports the core RPCs (PING, STORE, FIND_NODE and
/// FIND_VALUE) and maintains a routing table composed of `k`-buckets.  The
/// implementation is intentionally lightweight and omits many production
/// concerns (timeouts, parallel lookups and bucket refresh scheduling) but it
/// provides the full algorithmic building blocks required for a functional
/// Kademlia network.
final class KademliaNode {
    // MARK: - Nested Types

    /// Representation of a remote node in the network.
    struct Peer: Codable, Hashable {
        let id: UInt64
        let host: String
        let port: UInt16
    }

    /// Messages exchanged between nodes.  Each message carries the sender's ID
    /// so recipients can update their routing tables.
    private struct Message: Codable {
        enum Kind: String, Codable { case ping, pong, store, findNode, nodes, findValue, value }
        let kind: Kind
        let nodeID: UInt64
        let key: UInt64?
        let value: String?
        let nodes: [Peer]?
    }

    // MARK: - Public Configuration

    /// Kademlia constants.  `k` is the bucket size and `alpha` controls how
    /// many peers are queried in parallel during lookups.
    private let k = 20
    private let alpha = 3

    /// Identifier of this node and the UDP port it listens on.
    let id: UInt64
    let port: UInt16

    // MARK: - Private State

    private var buckets: [[Peer]] = Array(repeating: [], count: 64)
    private var store: [UInt64: String] = [:]
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "Kademlia")

    // Pending lookup completions keyed by the lookup key.
    private var pendingLookups: [UInt64: (String?) -> Void] = [:]

    // MARK: - Initialisation

    init(id: UInt64 = UInt64.random(in: 0..<UInt64.max), port: UInt16) {
        self.id = id
        self.port = port
    }

    // MARK: - Public API

    /// Start listening for UDP traffic.
    func start() throws {
        listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn)
        }
        listener?.start(queue: queue)
    }

    /// Stop the UDP listener.
    func stop() {
        listener?.cancel()
        listener = nil
    }

    /// Join an existing network by contacting a bootstrap node.  The bootstrap
    /// peer is added to the routing table and a `FIND_NODE` lookup for our own
    /// ID is performed to populate the table with additional peers.
    func join(bootstrapHost host: String, port: UInt16) {
        let peer = Peer(id: 0, host: host, port: port)
        update(peer: peer)
        let msg = Message(kind: .findNode, nodeID: id, key: id, value: nil, nodes: nil)
        send(msg, to: peer, expectResponse: false)
    }

    /// Store a key/value pair in the DHT.  The value is kept locally and
    /// replicated to the `k` closest known peers to the key.
    func store(value: String, for key: UInt64) {
        store[key] = value
        let peers = closestPeers(to: key, count: k)
        for peer in peers {
            let msg = Message(kind: .store, nodeID: id, key: key, value: value, nodes: nil)
            send(msg, to: peer, expectResponse: false)
        }
    }

    /// Find the value associated with a key.  A simplified iterative lookup is
    /// performed: query the closest peer, then continue with any peers returned
    /// until a value is found or no closer peers remain.
    func findValue(for key: UInt64, completion: @escaping (String?) -> Void) {
        if let value = store[key] { completion(value); return }

        var queried: Set<Peer> = []
        var candidates = closestPeers(to: key, count: k)

        func step() {
            guard !candidates.isEmpty else { completion(nil); return }
            let peer = candidates.removeFirst()
            queried.insert(peer)
            let msg = Message(kind: .findValue, nodeID: id, key: key, value: nil, nodes: nil)
            send(msg, to: peer, expectResponse: true) { [weak self] response in
                guard let self else { return }
                guard let response = response else { step(); return }
                switch response.kind {
                case .value:
                    completion(response.value)
                case .nodes:
                    // Merge returned peers and continue searching.
                    for p in response.nodes ?? [] {
                        let peer = Peer(id: p.id, host: p.host, port: p.port)
                        self.update(peer: peer)
                        if !queried.contains(peer) && !candidates.contains(peer) {
                            candidates.append(peer)
                        }
                    }
                    candidates.sort(by: { ($0.id ^ key) < ($1.id ^ key) })
                    step()
                default:
                    step()
                }
            }
        }

        step()
    }

    // MARK: - Routing Table

    /// Update the routing table with a peer contact.
    private func update(peer: Peer) {
        guard peer.id != id else { return }
        let index = bucketIndex(for: peer.id)
        var bucket = buckets[index]
        if let existing = bucket.firstIndex(of: peer) {
            // Move to the end to mark it as most recently seen.
            bucket.remove(at: existing)
            bucket.append(peer)
        } else {
            if bucket.count >= k { bucket.removeFirst() }
            bucket.append(peer)
        }
        buckets[index] = bucket
    }

    /// Return the `count` peers with IDs closest to the supplied key.
    private func closestPeers(to key: UInt64, count: Int) -> [Peer] {
        var all: [Peer] = buckets.flatMap { $0 }
        all.sort(by: { ($0.id ^ key) < ($1.id ^ key) })
        return Array(all.prefix(count))
    }

    /// Determine which bucket a node ID belongs in.
    private func bucketIndex(for nodeID: UInt64) -> Int {
        let distance = id ^ nodeID
        if distance == 0 { return 0 }
        return 63 - distance.leadingZeroBitCount
    }

    // MARK: - Networking

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receiveMessage { [weak self] data, _, _, _ in
            guard let self, let data = data,
                  let msg = try? JSONDecoder().decode(Message.self, from: data) else {
                connection.cancel(); return
            }
            self.process(message: msg, from: connection)
            connection.cancel()
        }
    }

    private func process(message: Message, from connection: NWConnection) {
        guard case let NWEndpoint.hostPort(host: host, port: port) = connection.endpoint else { return }
        let peer = Peer(id: message.nodeID, host: host.debugDescription, port: UInt16(port.rawValue))
        update(peer: peer)

        switch message.kind {
        case .ping:
            let pong = Message(kind: .pong, nodeID: id, key: nil, value: nil, nodes: nil)
            send(pong, to: peer, expectResponse: false)
        case .pong:
            break // routing table was updated above
        case .store:
            if let key = message.key, let value = message.value {
                store[key] = value
            }
        case .findNode:
            guard let key = message.key else { return }
            let peers = closestPeers(to: key, count: k)
            let reply = Message(kind: .nodes, nodeID: id, key: key, value: nil, nodes: peers)
            send(reply, to: peer, expectResponse: false)
        case .findValue:
            guard let key = message.key else { return }
            if let value = store[key] {
                let reply = Message(kind: .value, nodeID: id, key: key, value: value, nodes: nil)
                send(reply, to: peer, expectResponse: false)
            } else {
                let peers = closestPeers(to: key, count: k)
                let reply = Message(kind: .nodes, nodeID: id, key: key, value: nil, nodes: peers)
                send(reply, to: peer, expectResponse: false)
            }
        case .nodes:
            // Nodes responses are handled by the send callback in `findValue`.
            break
        case .value:
            // Value responses are handled by the send callback in `findValue`.
            break
        }
    }

    /// Send a message to a peer. If `expectResponse` is true a single response
    /// will be captured and delivered to the callback.
    private func send(_ message: Message, to peer: Peer, expectResponse: Bool,
                      completion: ((Message?) -> Void)? = nil) {
        let connection = NWConnection(host: NWEndpoint.Host(peer.host),
                                      port: NWEndpoint.Port(rawValue: peer.port)!,
                                      using: .udp)
        connection.start(queue: queue)
        guard let data = try? JSONEncoder().encode(message) else {
            connection.cancel(); completion?(nil); return
        }

        connection.send(content: data, completion: .contentProcessed { _ in
            if expectResponse {
                connection.receiveMessage { data, _, _, _ in
                    if let data,
                       let msg = try? JSONDecoder().decode(Message.self, from: data) {
                        completion?(msg)
                    } else {
                        completion?(nil)
                    }
                    connection.cancel()
                }
            } else {
                completion?(nil)
                connection.cancel()
            }
        })
    }
}
