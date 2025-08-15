//
//  ContentView.swift
//  weave
//
//  Created by Keios on 8/12/25.
//

import SwiftUI

/// Simple view demonstrating peer-to-peer connections without
/// relying on any central server. Users can listen on a port,
/// connect to a remote peer, and exchange text messages.
struct ContentView: View {
    @StateObject private var manager = PeerConnectionManager()
    @State private var listenPort: String = "8888"
    @State private var remoteHost: String = ""
    @State private var remotePort: String = ""
    @State private var message: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("Listen Port", text: $listenPort)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Start") {
                    if let port = UInt16(listenPort) {
                        manager.startListening(on: port)
                    }
                }
            }
            HStack {
                TextField("Remote Host", text: $remoteHost)
                    .textFieldStyle(.roundedBorder)
                TextField("Remote Port", text: $remotePort)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Connect") {
                    if let port = UInt16(remotePort) {
                        manager.connect(to: remoteHost, port: port)
                    }
                }
            }
            List(manager.messages, id: \.self) { msg in
                Text(msg)
            }
            HStack {
                TextField("Message", text: $message)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    manager.send(message)
                    message = ""
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
