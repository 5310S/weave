import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var manager = P2PManager(port: 9999)
    @State private var bootstrapHost: String = ""
    @State private var peerID: String = ""
    @State private var outgoing: String = ""
    @State private var showError: Bool = false
    @State private var debugLogs: [String] = [] // New: Store debug messages

    var body: some View {
        VStack(spacing: 20) {
            // Status and Info Section
            VStack {
                Text("Your Node ID: \(manager.nodeID)")
                    .font(.headline)
                Text("Your Address: \(manager.publicAddress.isEmpty ? "?" : manager.publicAddress):\(manager.publicPort)")
                    .font(.subheadline)
                Text("Status: \(manager.connectionStatus)")
                    .font(.subheadline)
                #if os(iOS)
                Button("Copy Address") {
                    UIPasteboard.general.string = "\(manager.publicAddress):\(manager.publicPort)"
                    debugLogs.append("[\(formattedTime())] Copied address: \(manager.publicAddress):\(manager.publicPort)")
                }
                #elseif os(macOS)
                Button("Copy Address") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(manager.publicAddress):\(manager.publicPort)", forType: .string)
                    debugLogs.append("[\(formattedTime())] Copied address: \(manager.publicAddress):\(manager.publicPort)")
                }
                #endif
                Button("Retry Address Fetch") {
                    print("Retrying address fetch")
                    debugLogs.append("[\(formattedTime())] Retrying address fetch")
                    manager.fetchPublicIP()
                }
                .opacity(manager.publicAddress.isEmpty ? 1 : 0)
            }
            // Network Join Section
            HStack {
                TextField("Bootstrap Host", text: $bootstrapHost)
                    .textFieldStyle(.roundedBorder)
                Button("Join Network") {
                    print("Joining network with bootstrap host: \(bootstrapHost)")
                    debugLogs.append("[\(formattedTime())] Joining network with bootstrap host: \(bootstrapHost)")
                    manager.joinNetwork(bootstrapHost: bootstrapHost, port: 9999)
                    manager.storePublicAddress()
                }
            }
            // Connect Section
            HStack {
                TextField("Peer ID", text: $peerID)
                    .textFieldStyle(.roundedBorder)
                Button("Connect") {
                    print("Connect button tapped with peer ID: \(peerID)")
                    if let id = UInt64(peerID) {
                        debugLogs.append("[\(formattedTime())] Connecting to peer ID: \(peerID)")
                        manager.connect(toPeerWithID: id)
                    } else {
                        manager.connectionStatus = "Invalid peer ID"
                        debugLogs.append("[\(formattedTime())] Invalid peer ID: \(peerID)")
                        showError = true
                    }
                }
            }
            // Message Section
            HStack {
                TextField("Message", text: $outgoing)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    print("Send button tapped with message: \(outgoing)")
                    debugLogs.append("[\(formattedTime())] Sending message: \(outgoing)")
                    manager.send(outgoing)
                    outgoing = ""
                }
            }
            // Message List
            List(manager.messages, id: \.self) { msg in
                Text(msg)
            }
            // Debug Log Section
            VStack(alignment: .leading) {
                Text("Debug Logs")
                    .font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(debugLogs.reversed(), id: \.self) { log in
                            Text(log)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .border(Color.gray.opacity(0.2), width: 1)
            }
        }
        .padding()
        .onAppear {
            print("ContentView appeared")
            debugLogs.append("[\(formattedTime())] App started")
            manager.startListening(on: 9999)
            manager.fetchPublicIP()
        }
        .onChange(of: manager.connectionStatus) { newStatus in
            debugLogs.append("[\(formattedTime())] Connection status: \(newStatus)")
            if newStatus.contains("failed") || newStatus.contains("error") {
                showError = true
            }
        }
        .onChange(of: manager.messages) { newMessages in
            if let lastMessage = newMessages.last {
                debugLogs.append("[\(formattedTime())] Received message: \(lastMessage)")
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(manager.connectionStatus),
                primaryButton: .default(Text("Retry")) {
                    debugLogs.append("[\(formattedTime())] Retrying due to error: \(manager.connectionStatus)")
                    manager.fetchPublicIP()
                    showError = false
                },
                secondaryButton: .cancel {
                    showError = false
                }
            )
        }
    }

    // Helper to format timestamp for debug logs
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

#Preview {
    ContentView()
}
