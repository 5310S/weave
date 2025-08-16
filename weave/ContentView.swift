//
//  ContentView.swift
//  weave
//
//  Created by keios on 8/15/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var manager = P2PManager()
    @State private var host: String = ""
    @State private var port: String = "9999"
    @State private var outgoing: String = ""

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("Your Address: \(manager.publicAddress.isEmpty ? "?" : manager.publicAddress):\(port)")
#if os(iOS)
                Button("Copy Address") {
                    UIPasteboard.general.string = "\(manager.publicAddress):\(port)"
                }
#elseif os(macOS)
                Button("Copy Address") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(manager.publicAddress):\(port)", forType: .string)
                }
#endif
            }
            HStack {
                TextField("Host", text: $host)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Button("Connect") {
                    print("Connect button tapped with host: \(host) port: \(port)")
                    if let p = UInt16(port) {
                        manager.connect(to: host, port: p)
                    }
                }
            }

            HStack {
                TextField("Message", text: $outgoing)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    print("Send button tapped with message: \(outgoing)")
                    manager.send(outgoing)
                    outgoing = ""
                }
            }

            List(manager.messages, id: \.self) { msg in
                Text(msg)
            }
        }
        .padding()
        .onAppear {
            print("ContentView appeared")
            if let p = UInt16(port) {
                manager.startListening(on: p)
            }
            manager.fetchPublicIP()
        }
    }
}

#Preview {
    ContentView()
}
