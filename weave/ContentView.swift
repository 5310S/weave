import SwiftUI
import weave
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
            VStack {
                Text("Your Node ID: \(manager.nodeID)")
                Text("Your Address: \(manager.publicAddress.isEmpty ? "?" : manager.publicAddress):\(manager.publicPort)")
                Text("Status: \(manager.connectionStatus)")
                #if os(iOS)
                Button("Copy Address") {
                    UIPasteboard.general.string = "\(manager.publicAddress):\(manager.publicPort)"
                }
                #elseif os(macOS)
                Button("Copy Address") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(manager.publicAddress):\(manager.publicPort)", forType: .string)
                }
                #endif
                Button("Retry Address Fetch") {
                    manager.log("Retry Address Fetch tapped")
                    manager.fetchPublicIP()
                }
                .opacity(manager.publicAddress.isEmpty ? 1 : 0)
            }
            HStack {
                TextField("Bootstrap Host", text: $bootstrapHost)
                    .textFieldStyle(.roundedBorder)
                Button("Join Network") {
                    manager.log("Join Network tapped with bootstrap host: \(bootstrapHost)")
                    manager.joinNetwork(bootstrapHost: bootstrapHost, port: 9999)
                    manager.storePublicAddress()
                }
            }
            HStack {
                TextField("Peer ID", text: $peerID)
                    .textFieldStyle(.roundedBorder)
                Button("Connect") {
                    manager.log("Connect tapped with peer ID: \(peerID)")
                    if let id = UInt64(peerID) {
                        manager.connect(toPeerWithID: id)
                    } else {
                        manager.connectionStatus = "Invalid peer ID"
                        showError = true
                        manager.log("Invalid peer ID entered")
                    }
                }
            }
            HStack {
                TextField("Message", text: $outgoing)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    manager.log("Send tapped with message: \(outgoing)")
                    manager.send(outgoing)
                    outgoing = ""
                }
            }
            List {
                Section(header: Text("Messages")) {
                    ForEach(manager.messages, id: \.self) { msg in
                        Text(msg)
                    }
                }
                Section(header: Text("Debug Logs")) {
                    ForEach(manager.logs, id: \.self) { log in
                        Text(log)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            manager.log("ContentView appeared")
            manager.startListening(on: 9999)
            manager.fetchPublicIP()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(manager.connectionStatus),
                primaryButton: .default(Text("Retry")) {
                    manager.log("Retry after error")
                    manager.fetchPublicIP()
                    showError = false
                },
                secondaryButton: .cancel {
                    showError = false
                    manager.log("Error alert dismissed")
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
