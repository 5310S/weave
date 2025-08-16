//
//  ContentView.swift
//  weave
//
//  Created by keios on 8/15/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = P2PManager()
    @State private var host: String = ""
    @State private var port: String = "9999"
    @State private var outgoing: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                TextField("Host", text: $host)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Button("Connect") {
                    if let p = UInt16(port) {
                        manager.connect(to: host, port: p)
                    }
                }
            }

            HStack {
                TextField("Message", text: $outgoing)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
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
            if let p = UInt16(port) {
                manager.startListening(on: p)
            }
        }
    }
}

#Preview {
    ContentView()
}
