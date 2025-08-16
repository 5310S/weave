import Foundation
import Network
import Combine

/// Manages a basic peer-to-peer TCP connection with no central server.
/// Each instance can listen for incoming peers and initiate connections to
/// a known host. Received text messages are published via the `messages` array.
class P2PManager: ObservableObject {
    @Published var messages: [String] = []
    @Published var publicAddress: String = ""

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "P2PManager")

    private let debugLogsEnabled = true
    private func log(_ message: String) {
        guard debugLogsEnabled else { return }
        print("[P2PManager] \(message)")
    }

    /// Start listening for incoming peer connections on the provided port.
    func startListening(on port: UInt16) {
        log("startListening on port \(port)")
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                self?.log("Listener state changed: \(state)")
            }
            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.log("Accepted new incoming connection")
                self?.setupConnection(newConnection)
                newConnection.start(queue: self?.queue ?? .main)
            }
            listener?.start(queue: queue)
            log("Listening started")
        } catch {
            log("Listener failed to start: \(error)")
        }
    }

    /// Indicates whether the manager is currently listening for peers.
    var isListening: Bool {
        listener != nil
    }

    /// Retrieve the device's public IP address for sharing with peers.
    func fetchPublicIP() {
        log("Fetching public IP")
        guard let url = URL(string: "https://api.ipify.org?format=text") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data, let ip = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.publicAddress = trimmed
                    self?.log("Public IP fetched: \(trimmed)")
                }
            }
        }.resume()
    }

    /// Connect to a remote peer at the given host and port.
    func connect(to host: String, port: UInt16) {
        log("Attempting to connect to \(host):\(port)")
        connection = NWConnection(host: NWEndpoint.Host(host),
                                  port: NWEndpoint.Port(rawValue: port)!,
                                  using: .tcp)
        connection?.stateUpdateHandler = { [weak self] newState in
            self?.log("Connection state changed: \(newState)")
            if case .failed(let error) = newState {
                self?.log("Connection failed: \(error)")
            }
        }
        connection?.start(queue: queue)
        log("Connection started")
        setupReceive()
    }

    /// Send a string message to the connected peer.
    func send(_ text: String) {
        log("Sending message: \(text)")
        guard let connection else {
            log("Cannot send, no active connection")
            return
        }
        let data = text.data(using: .utf8) ?? Data()
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func setupConnection(_ connection: NWConnection) {
        log("Setting up connection")
        self.connection = connection
        setupReceive()
    }

    private func setupReceive() {
        log("Preparing to receive data")
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, isComplete, error in
            if let data, let text = String(data: data, encoding: .utf8) {
                self?.log("Received message: \(text)")
                DispatchQueue.main.async {
                    self?.messages.append(text)
                }
            }
            if let error {
                self?.log("Receive error: \(error)")
            }
            if isComplete {
                self?.log("Receive completed")
            }
            if error == nil && !isComplete {
                self?.setupReceive()
            }
        }
    }
}
