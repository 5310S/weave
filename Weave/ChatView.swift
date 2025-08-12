import SwiftUI

/// Simple chat view backed by a ``PeerConnection``. Displays a list of
/// received and sent messages and provides a text field to compose new
/// messages.
struct ChatView: View {
    @StateObject private var connection = PeerConnection()
    @State private var message: String = ""

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(connection.messages.enumerated()), id: \.offset) { _, msg in
                        Text(msg)
                            .frame(maxWidth: .infinity, alignment: msg.starts(with: "Me:") ? .trailing : .leading)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            HStack {
                TextField("Message", text: $message)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    connection.send(text: text)
                    message = ""
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
}
