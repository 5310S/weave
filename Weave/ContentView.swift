//
//  ContentView.swift
//  Weave
//
//  Created by Keios on 8/10/25.
//

import SwiftUI

/// Root view for the application. Displays the chat interface so two
/// peers can exchange messages once a connection is established.
struct ContentView: View {
    var body: some View {
        ChatView()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
