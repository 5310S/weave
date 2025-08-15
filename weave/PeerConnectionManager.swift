import Foundation
import Network
import SwiftUI

/// Simple peer-to-peer connection manager using TCP sockets.
/// It allows listening on a port, connecting to a remote host,
/// and sending text messages. This avoids any central server by
/// relying on direct socket connections between peers.
@MainActor
final class PeerConnectionManager: ObservableObject {
    @Published var messages: [String] = []
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    /// Start listening for incoming connections on a given port.
    func startListening(on port: UInt16) {
        do {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            listener = try NWListener(using: .tcp, on: nwPort)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.setupReceive(on: connection)
                self?.connections.append(connection)
                connection.start(queue: .main)
            }
            listener?.start(queue: .main)
            messages.append("Listening on port \(port)")
        } catch {
            messages.append("Failed to start listener: \(error.localizedDescription)")
        }
    }

    /// Connect to a remote peer identified by host and port.
    func connect(to host: String, port: UInt16) {
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        setupReceive(on: connection)
        connection.start(queue: .main)
        connections.append(connection)
        messages.append("Connecting to \(host):\(port)")
    }

    /// Send a text message to all connected peers.
    func send(_ text: String) {
        let data = text.data(using: .utf8) ?? Data()
        for connection in connections {
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    self?.messages.append("Send error: \(error.localizedDescription)")
                }
            })
        }
        messages.append("Me: \(text)")
    }

    private func setupReceive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let message = String(decoding: data, as: UTF8.self)
                self?.messages.append("Peer: \(message)")
            }
            if error == nil && !isComplete {
                self?.setupReceive(on: connection)
            }
        }
    }
}

