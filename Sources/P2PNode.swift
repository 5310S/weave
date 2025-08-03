import Foundation

/// A placeholder networking node that will integrate libp2p in the future.
/// For now it simply tracks bootstrap peers and whether the node is running.
final class P2PNode {
    /// Addresses of peers used to join the wider network.
    private let bootstrapPeers: [String]
    /// Indicates whether the node is actively running.
    private(set) var isRunning: Bool = false

    init(bootstrapPeers: [String] = []) {
        self.bootstrapPeers = bootstrapPeers
    }

    /// Starts the networking stack. In a real implementation this would
    /// initialise libp2p, perform NAT traversal and begin listening for peers.
    func start() {
        isRunning = true
    }

    /// Stops the networking stack and cleans up resources.
    func stop() {
        isRunning = false
    }
}

