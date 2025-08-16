import Foundation
import Network

/// A lightweight and highly simplified Kademlia node. It is **not** a complete
/// implementation of the Kademlia specification but provides enough behaviour
/// to demonstrate how peers can discover each other and exchange key/value
/// data without a central server.
///
/// Each node listens on a UDP port. Messages are sent as small JSON blobs
/// describing the action (ping, store, findValue, etc.). The routing logic is
/// extremely small: peers are kept in a flat set and lookups simply forward the
/// query to the peer whose identifier is closest to the key being searched for.
final class KademliaNode {
    // MARK: - Nested Types

    /// Representation of a remote peer.
    struct Peer: Hashable {
        let id: UInt64
        let host: NWEndpoint.Host
        let port: UInt16
    }

    /// Message exchanged between nodes. Only a tiny subset of the real protocol
    /// is modelled here and the payload is intentionally small.
    private struct Message: Codable {
        enum Kind: String, Codable { case ping, pong, store, findValue, value }
        let kind: Kind
        let nodeID: UInt64
        let key: UInt64?
        let value: String?
    }

    // MARK: - Public Properties

    let id: UInt64
    let port: UInt16

    // MARK: - Private State

    private var peers: Set<Peer> = []
    private var store: [UInt64: String] = [:]
    private var listener: NWListener?
    private var pendingLookups: [UInt64: (String?) -> Void] = [:]
    private let queue = DispatchQueue(label: "KademliaNode")

    // MARK: - Initialisation

    init(id: UInt64 = UInt64.random(in: 0..<UInt64.max), port: UInt16) {
        self.id = id
        self.port = port
    }

    // MARK: - Network Lifecycle

    /// Begin listening for UDP messages.
    func start() throws {
        listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener?.start(queue: queue)
    }

    /// Stop listening for messages.
    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Kademlia Operations

    /// Join the network by pinging a known bootstrap peer. The bootstrap host and
    /// port must already be listening.
    func join(bootstrapHost host: String, port: UInt16) {
        let peer = Peer(id: 0, host: NWEndpoint.Host(host), port: port)
        peers.insert(peer)
        let ping = Message(kind: .ping, nodeID: id, key: nil, value: nil)
        send(ping, to: peer)
    }

    /// Store a key/value pair locally and replicate to all known peers. A real
    /// implementation would replicate to the `k` closest peers instead.
    func store(value: String, for key: UInt64) {
        store[key] = value
        for peer in peers {
            let msg = Message(kind: .store, nodeID: id, key: key, value: value)
            send(msg, to: peer)
        }
    }

    /// Attempt to find the value for the provided key. If the value is not
    /// stored locally the request is sent to the closest known peer. The result
    /// is delivered asynchronously via the completion handler.
    func findValue(for key: UInt64, completion: @escaping (String?) -> Void) {
        if let value = store[key] {
            completion(value)
            return
        }
        guard let peer = peers.min(by: { ($0.id ^ key) < ($1.id ^ key) }) else {
            completion(nil)
            return
        }
        pendingLookups[key] = completion
        let msg = Message(kind: .findValue, nodeID: id, key: key, value: nil)
        send(msg, to: peer)
    }

    // MARK: - Message Handling

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receiveMessage { [weak self] data, _, _, _ in
            if let data = data, let msg = try? JSONDecoder().decode(Message.self, from: data) {
                self?.process(message: msg, from: connection)
            }
            connection.cancel()
        }
    }

    private func process(message: Message, from connection: NWConnection) {
        guard case let NWEndpoint.hostPort(host: host, port: port) = connection.endpoint else { return }
        let peer = Peer(id: message.nodeID, host: host, port: UInt16(port.rawValue))
        switch message.kind {
        case .ping:
            peers.insert(peer)
            let pong = Message(kind: .pong, nodeID: id, key: nil, value: nil)
            send(pong, to: peer)
        case .pong:
            peers.insert(peer)
        case .store:
            if let key = message.key, let value = message.value {
                store[key] = value
            }
        case .findValue:
            guard let key = message.key else { return }
            if let value = store[key] {
                let reply = Message(kind: .value, nodeID: id, key: key, value: value)
                send(reply, to: peer)
            } else if let next = peers.min(by: { ($0.id ^ key) < ($1.id ^ key) }) {
                // Naively forward the query to the next closest peer.
                send(message, to: next)
            }
        case .value:
            guard let key = message.key else { return }
            let callback = pendingLookups.removeValue(forKey: key)
            callback?(message.value)
        }
    }

    private func send(_ message: Message, to peer: Peer) {
        let connection = NWConnection(host: peer.host, port: NWEndpoint.Port(rawValue: peer.port)!, using: .udp)
        connection.start(queue: queue)
        if let data = try? JSONEncoder().encode(message) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            connection.cancel()
        }
    }
}
