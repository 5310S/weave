import Foundation
import Network
import Combine

class P2PManager: ObservableObject {
    @Published var messages: [String] = []
    @Published var publicAddress: String = ""
    @Published var publicPort: UInt16 = 9999
    @Published var connectionStatus: String = "Disconnected"
    @Published var logs: [String] = []
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "P2PManager")
    private let kademlia: KademliaNode
    public var nodeID: UInt64 { kademlia.id }
    private let debugLogsEnabled = true

    init(port: UInt16) {
        self.kademlia = KademliaNode(id: UInt64.random(in: 0..<UInt64.max), port: port)
        do {
            try kademlia.start()
            log("Kademlia DHT started on port \(port)")
        } catch {
            log("Kademlia failed to start: \(error)")
        }
    }

    func log(_ message: String) {
        guard debugLogsEnabled else { return }
        print("[P2PManager] \(message)")
        DispatchQueue.main.async {
            self.logs.append(message)
        }
    }

    func startListening(on port: UInt16) {
        log("startListening on port \(port)")
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.serviceClass = .responsiveData
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                self.log("Listener state changed: \(state)")
                DispatchQueue.main.async {
                    self.connectionStatus = "\(state)"
                }
            }
            listener?.newConnectionHandler = { [weak self] newConnection in
                guard let self else { return }
                self.log("Accepted new incoming connection")
                self.setupConnection(newConnection)
                newConnection.start(queue: self.queue)
            }
            listener?.start(queue: queue)
            log("Listening started successfully")
        } catch {
            log("Listener failed to start: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Failed to start: \(error)"
            }
        }
    }

    var isListening: Bool {
        listener != nil
    }

    func fetchPublicIP() {
        log("Fetching public IP and port with STUN")
        let servers = [
            ("stun.l.google.com", UInt16(19302)),
            ("stun.ekiga.net", UInt16(3478)),
            ("stun.voipbuster.com", UInt16(3478)),
            ("stun.sipgate.net", UInt16(3478)),
            ("stun.nextcloud.com", UInt16(3478))
        ]
        func tryServer(index: Int) {
            guard index < servers.count else {
                log("All STUN servers failed, falling back to HTTP")
                guard let url = URL(string: "https://api.ipify.org?format=text") else {
                    DispatchQueue.main.async {
                        self.connectionStatus = "HTTP fallback URL invalid"
                    }
                    return
                }
                URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                    guard let self else { return }
                    if let error {
                        self.log("HTTP IP fetch error: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.connectionStatus = "HTTP IP fetch failed: \(error.localizedDescription)"
                        }
                        return
                    }
                    guard let data, let ip = String(data: data, encoding: .utf8) else {
                        DispatchQueue.main.async {
                            self.connectionStatus = "HTTP IP fetch returned no data"
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.publicAddress = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.publicPort = 9999
                        self.log("HTTP public IP: \(self.publicAddress), port: 9999")
                        self.storePublicAddress()
                    }
                }.resume()
                return
            }
            let (server, port) = servers[index]
            log("Trying STUN server: \(server):\(port)")
            let stunClient = STUNClient(server: server, port: port)
            stunClient.getPublicAddress { [weak self] ip, port, error in
                guard let self else { return }
                if let error {
                    self.log("STUN error on \(server): \(error.localizedDescription)")
                    tryServer(index: index + 1)
                    return
                }
                if let ip, let port {
                    DispatchQueue.main.async {
                        self.publicAddress = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.publicPort = port
                        self.log("STUN public IP: \(ip), port: \(port)")
                        self.storePublicAddress()
                    }
                } else {
                    tryServer(index: index + 1)
                }
            }
        }
        tryServer(index: 0)
    }

    func connect(toPeerWithID peerID: UInt64) {
        log("Searching for peer with ID \(peerID)")
        kademlia.findValue(for: peerID) { [weak self] value in
            guard let self else { return }
            guard let value, let peerData = value.data(using: .utf8),
                  let peer = try? JSONDecoder().decode(KademliaNode.Peer.self, from: peerData) else {
                DispatchQueue.main.async {
                    self.connectionStatus = "Peer not found or invalid data"
                }
                return
            }
            log("Found peer: \(peer.host):\(peer.port)")
            self.connect(to: peer.host, port: peer.port)
        }
    }

    func connect(to host: String, port: UInt16) {
        log("Attempting to connect to \(host):\(port)")
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.log("Connection state changed: \(state)")
            DispatchQueue.main.async {
                self.connectionStatus = "\(state)"
            }
            if case .failed(let error) = state {
                self.log("Connection failed: \(error)")
            }
        }
        connection?.start(queue: queue)
        log("Connection started")
        setupReceive()
    }

    func send(_ text: String) {
        log("Sending message: \(text)")
        guard let connection else {
            log("Cannot send, no active connection")
            DispatchQueue.main.async {
                self.connectionStatus = "No active connection"
            }
            return
        }
        let data = text.data(using: .utf8) ?? Data()
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.log("Send error: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Send failed: \(error)"
                }
            }
        })
    }

    func storePublicAddress() {
        guard !publicAddress.isEmpty else { return }
        let peer = KademliaNode.Peer(id: kademlia.id, host: publicAddress, port: publicPort)
        if let data = try? JSONEncoder().encode(peer) {
            kademlia.store(value: String(data: data, encoding: .utf8) ?? "", for: kademlia.id)
            log("Stored public address in DHT: \(publicAddress):\(publicPort) for ID \(kademlia.id)")
        }
    }

    func joinNetwork(bootstrapHost: String, port: UInt16) {
        kademlia.join(bootstrapHost: bootstrapHost, port: port)
        log("Joined DHT network via \(bootstrapHost):\(port)")
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
        }
        log("Disconnected")
    }

    private func setupConnection(_ connection: NWConnection) {
        log("Setting up connection")
        self.connection = connection
        setupReceive()
    }

    private func setupReceive() {
        log("Preparing to receive data")
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, let text = String(data: data, encoding: .utf8) {
                self.log("Received message: \(text)")
                DispatchQueue.main.async {
                    self.messages.append(text)
                }
            }
            if let error {
                self.log("Receive error: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = "Receive error: \(error)"
                }
            }
            if isComplete {
                self.log("Receive completed")
                DispatchQueue.main.async {
                    self.connectionStatus = "Connection closed"
                }
            }
            if error == nil && !isComplete {
                self.setupReceive()
            }
        }
    }
}

class STUNClient {
    private let server: String
    private let port: UInt16

    init(server: String, port: UInt16) {
        self.server = server
        self.port = port
    }

    func getPublicAddress(completion: @escaping (String?, UInt16?, Error?) -> Void) {
        let connection = NWConnection(host: NWEndpoint.Host(server), port: NWEndpoint.Port(rawValue: port)!, using: .udp)
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                var stunRequest = Data()
                stunRequest.append(contentsOf: [0x00, 0x01]) // BINDING request
                stunRequest.append(contentsOf: [0x00, 0x00]) // Message length (no attributes)
                stunRequest.append(contentsOf: [0x21, 0x12, 0xA4, 0x42]) // Magic cookie
                let transactionID = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
                stunRequest.append(transactionID)
                connection.send(content: stunRequest, completion: .contentProcessed { error in
                    if let error {
                        completion(nil, nil, error)
                        return
                    }
                })
            } else if case .failed(let error) = state {
                completion(nil, nil, error)
                return
            }
        }
        connection.receive(minimumIncompleteLength: 20, maximumLength: 65535) { data, _, _, error in
            defer { connection.cancel() }
            if let error {
                completion(nil, nil, error)
                return
            }
            guard let data, data.count >= 20 else {
                let error = NSError(domain: "STUNClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data or too short"])
                completion(nil, nil, error)
                return
            }
            self.log("STUN response from \(self.server): \(data.hexEncodedString())")
            guard data[0] == 0x01, data[1] == 0x01 else {
                let error = NSError(domain: "STUNClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid STUN response type: \(String(format: "%02x%02x", data[0], data[1]))"])
                completion(nil, nil, error)
                return
            }
            let messageLength = (UInt16(data[2]) << 8) + UInt16(data[3])
            guard data.count >= 20 + Int(messageLength) else {
                let error = NSError(domain: "STUNClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Incomplete STUN response, expected \(20 + Int(messageLength)), got \(data.count)"])
                completion(nil, nil, error)
                return
            }
            var offset = 20
            while offset + 4 <= data.count {
                let attrType = (UInt16(data[offset]) << 8) + UInt16(data[offset + 1])
                let attrLength = (UInt16(data[offset + 2]) << 8) + UInt16(data[offset + 3])
                self.log("Found attribute type: \(String(format: "%04x", attrType)), length: \(attrLength) at offset \(offset)")
                guard offset + 4 + Int(attrLength) <= data.count else {
                    let error = NSError(domain: "STUNClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Malformed attribute at offset \(offset), length \(attrLength)"])
                    completion(nil, nil, error)
                    return
                }
                self.log("Attribute data: \(Data(data[offset ..< min(offset + 4 + Int(attrLength), data.count)]).hexEncodedString())")
                if attrType == 0x0020 || attrType == 0x0001 { // XOR-MAPPED-ADDRESS or MAPPED-ADDRESS
                    guard offset + 8 <= data.count else {
                        let error = NSError(domain: "STUNClient", code: -5, userInfo: [NSLocalizedDescriptionKey: "Insufficient data for address at offset \(offset)"])
                        completion(nil, nil, error)
                        return
                    }
                    let family = data[offset + 5]
                    self.log("Family: \(String(format: "%02x", family))")
                    if family == 0x01 { // IPv4
                        let port = (UInt16(data[offset + 6]) << 8) + UInt16(data[offset + 7])
                        self.log("Raw port: \(port)")
                        let addressStart = offset + 8
                        let addressEnd = min(offset + 12, data.count)
                        guard addressEnd - addressStart == 4 else {
                            let error = NSError(domain: "STUNClient", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid IPv4 address length: \(addressEnd - addressStart) at offset \(offset)"])
                            completion(nil, nil, error)
                            return
                        }
                        let address = [UInt8](data[addressStart ..< addressEnd])
                        self.log("Raw address bytes: \(address.map { String($0) }.joined(separator: "."))")
                        if attrType == 0x0020 {
                            let xorPort = port ^ 0x2112
                            let xorAddress = address.enumerated().map { $0.element ^ [0x21, 0x12, 0xA4, 0x42][$0.offset] }
                            let ip = xorAddress.map { String($0) }.joined(separator: ".")
                            self.log("XOR-MAPPED-ADDRESS parsed: \(ip):\(xorPort)")
                            completion(ip, xorPort, nil)
                        } else {
                            let ip = address.map { String($0) }.joined(separator: ".")
                            self.log("MAPPED-ADDRESS parsed: \(ip):\(port)")
                            completion(ip, port, nil)
                        }
                        return
                    } else if family == 0x02 { // IPv6
                        let port = (UInt16(data[offset + 6]) << 8) + UInt16(data[offset + 7])
                        self.log("Raw port: \(port)")
                        let addressStart = offset + 8
                        let addressEnd = min(offset + 24, data.count)
                        guard addressEnd - addressStart == 16 else {
                            let error = NSError(domain: "STUNClient", code: -7, userInfo: [NSLocalizedDescriptionKey: "Invalid IPv6 address length: \(addressEnd - addressStart) at offset \(offset)"])
                            completion(nil, nil, error)
                            return
                        }
                        let address = [UInt8](data[addressStart ..< addressEnd])
                        self.log("Raw IPv6 address bytes: \(address.map { String(format: "%02x", $0) }.joined())")
                        if attrType == 0x0020 {
                            let xorPort = port ^ 0x2112
                            let xorAddress = address.enumerated().map { $0.element ^ [0x21, 0x12, 0xA4, 0x42, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0][$0.offset] }
                            let ip = xorAddress.withUnsafeBytes { ptr in
                                let groups = (0..<8).map { ptr.load(fromByteOffset: $0 * 2, as: UInt16.self).bigEndian }
                                return groups.map { String(format: "%04x", $0) }.joined(separator: ":")
                            }
                            self.log("XOR-MAPPED-ADDRESS (IPv6) parsed: \(ip):\(xorPort)")
                            completion(ip, xorPort, nil)
                        } else {
                            let ip = address.withUnsafeBytes { ptr in
                                let groups = (0..<8).map { ptr.load(fromByteOffset: $0 * 2, as: UInt16.self).bigEndian }
                                return groups.map { String(format: "%04x", $0) }.joined(separator: ":")
                            }
                            self.log("MAPPED-ADDRESS (IPv6) parsed: \(ip):\(port)")
                            completion(ip, port, nil)
                        }
                        return
                    }
                }
                let paddedLength = (Int(attrLength) + 3) & ~3
                offset += 4 + paddedLength
            }
            let error = NSError(domain: "STUNClient", code: -8, userInfo: [NSLocalizedDescriptionKey: "No valid address attribute found"])
            completion(nil, nil, error)
        }
        connection.start(queue: .global())
    }

    private func log(_ message: String) {
        print("[STUNClient] \(message)")
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
