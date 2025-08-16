import Foundation
import Network
import Combine

/// Manages a basic peer-to-peer TCP connection with no central server.
/// Each instance can listen for incoming peers and initiate connections to
/// a known host. Received text messages are published via the `messages` array.
class P2PManager: ObservableObject {
    @Published var messages: [String] = []

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "P2PManager")

    /// Start listening for incoming peer connections on the provided port.
    func startListening(on port: UInt16) {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.setupConnection(newConnection)
                newConnection.start(queue: self?.queue ?? .main)
            }
            listener?.start(queue: queue)
        } catch {
            print("Listener failed to start: \(error)")
        }
    }

    /// Indicates whether the manager is currently listening for peers.
    var isListening: Bool {
        listener != nil
    }

    /// Connect to a remote peer at the given host and port.
    func connect(to host: String, port: UInt16) {
        connection = NWConnection(host: NWEndpoint.Host(host),
                                  port: NWEndpoint.Port(rawValue: port)!,
                                  using: .tcp)
        connection?.stateUpdateHandler = { newState in
            if case .failed(let error) = newState {
                print("Connection failed: \(error)")
            }
        }
        connection?.start(queue: queue)
        setupReceive()
    }

    /// Send a string message to the connected peer.
    func send(_ text: String) {
        guard let connection else { return }
        let data = text.data(using: .utf8) ?? Data()
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func setupConnection(_ connection: NWConnection) {
        self.connection = connection
        setupReceive()
    }

    private func setupReceive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, isComplete, error in
            if let data, let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.messages.append(text)
                }
            }

            if error == nil && !isComplete {
                self?.setupReceive()
            }
        }
    }
}
