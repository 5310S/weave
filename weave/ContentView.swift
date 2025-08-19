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

    var body: some View {
        VStack(spacing: 20) {
            // Status and Info Section
            VStack(alignment: .center, spacing: 10) {
                Text("Your Node ID: \(manager.nodeID)")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Your Address: \(manager.publicAddress.isEmpty ? "?" : manager.publicAddress):\(manager.publicPort)")
                    .font(.subheadline)
                    .foregroundColor(manager.publicAddress.isEmpty ? .red : .green)
                Text("Status: \(manager.connectionStatus)")
                    .font(.subheadline)
                    .foregroundColor(manager.connectionStatus.contains("ready") ? .green : .red)
                #if os(iOS)
                Button(action: {
                    UIPasteboard.general.string = "\(manager.publicAddress):\(manager.publicPort)"
                    manager.debugEvents.append("[\(formattedTime())] Copied address: \(manager.publicAddress):\(manager.publicPort)")
                }) {
                    Text("Copy Address")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                #elseif os(macOS)
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(manager.publicAddress):\(manager.publicPort)", forType: .string)
                    manager.debugEvents.append("[\(formattedTime())] Copied address: \(manager.publicAddress):\(manager.publicPort)")
                }) {
                    Text("Copy Address")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                #endif
                Button(action: {
                    print("Retrying address fetch")
                    manager.debugEvents.append("[\(formattedTime())] Retrying address fetch")
                    manager.fetchPublicIP()
                }) {
                    Text("Retry Address Fetch")
                        .padding()
                        .background(manager.publicAddress.isEmpty ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .opacity(manager.publicAddress.isEmpty ? 1 : 0.5)
            }
            // Network Join Section
            HStack {
                TextField("Bootstrap Host", text: $bootstrapHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Button(action: {
                    print("Joining network with bootstrap host: \(bootstrapHost)")
                    manager.debugEvents.append("[\(formattedTime())] Joining network with bootstrap host: \(bootstrapHost)")
                    manager.joinNetwork(bootstrapHost: bootstrapHost, port: 9999)
                    manager.storePublicAddress()
                }) {
                    Text("Join Network")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            // Connect Section
            HStack {
                TextField("Peer ID", text: $peerID)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Button(action: {
                    print("Connect button tapped with peer ID: \(peerID)")
                    if let id = UInt64(peerID) {
                        manager.debugEvents.append("[\(formattedTime())] Connecting to peer ID: \(peerID)")
                        manager.connect(toPeerWithID: id)
                    } else {
                        manager.connectionStatus = "Invalid peer ID"
                        manager.debugEvents.append("[\(formattedTime())] Invalid peer ID: \(peerID)")
                        showError = true
                    }
                }) {
                    Text("Connect")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            // Message Section
            HStack {
                TextField("Message", text: $outgoing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Button(action: {
                    print("Send button tapped with message: \(outgoing)")
                    manager.debugEvents.append("[\(formattedTime())] Sending message: \(outgoing)")
                    manager.send(outgoing)
                    outgoing = ""
                }) {
                    Text("Send")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            // Message List
            List(manager.messages, id: \.self) { msg in
                Text(msg)
                    .font(.body)
            }
            .frame(maxHeight: 150)
            // Debug Log Section
            VStack(alignment: .leading) {
                Text("Debug Logs")
                    .font(.headline)
                    .foregroundColor(.purple)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(manager.debugEvents.reversed().prefix(20), id: \.self) { event in
                            Text(event)
                                .font(.caption)
                                .foregroundColor(event.contains("error") || event.contains("failed") || event.contains("Invalid") ? .red : event.contains("success") || event.contains("Connected") || event.contains("Received") ? .green : .gray)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .border(Color.gray.opacity(0.2), width: 1)
                .padding(.top, 5)
            }
        }
        .padding()
        .onAppear {
            print("ContentView appeared")
            manager.debugEvents.append("[\(formattedTime())] App started")
            manager.startListening(on: 9999)
            manager.fetchPublicIP()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage()),
                primaryButton: .default(Text("Retry")) {
                    manager.debugEvents.append("[\(formattedTime())] Retrying due to error: \(manager.connectionStatus)")
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

    // Helper to provide detailed error messages
    private func errorMessage() -> String {
        if manager.connectionStatus.contains("STUN failed") {
            return "\(manager.connectionStatus)\nTry switching to Wi-Fi or tap Retry."
        } else if manager.connectionStatus.contains("Peer not found") {
            return "\(manager.connectionStatus)\nCheck the peer ID and ensure both devices are in the same network."
        } else if manager.connectionStatus.contains("Invalid peer ID") {
            return "\(manager.connectionStatus)\nEnter a valid numeric peer ID."
        } else if manager.connectionStatus.contains("Connection failed") {
            return "\(manager.connectionStatus)\nEnsure the peer's address is reachable and port 9999 is open."
        } else {
            return manager.connectionStatus
        }
    }
}

#Preview {
    ContentView()
}
