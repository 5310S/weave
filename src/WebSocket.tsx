import { useEffect, useState } from "react";

const WebSocketClient: React.FC = () => {
  const [socket, setSocket] = useState<WebSocket | null>(null);
  const [messages, setMessages] = useState<string[]>([]);
  const [input, setInput] = useState<string>("");
  const [status, setStatus] = useState<string>("Connecting...");

  useEffect(() => {
    const ws = new WebSocket("ws://82.25.86.57:8081");
    setSocket(ws);

    ws.onopen = () => {
      setStatus("WebSocket connected");
      setMessages((msgs) => [...msgs, "WebSocket connected"]);
    };

    ws.onmessage = (event: MessageEvent) => {
      setMessages((msgs) => [...msgs, `Received: ${event.data}`]);
    };

    ws.onclose = () => {
      setStatus("WebSocket closed");
      setMessages((msgs) => [...msgs, "WebSocket closed"]);
    };

    ws.onerror = (err) => {
      setStatus("WebSocket error");
      setMessages((msgs) => [...msgs, "WebSocket error"]);
    };

    return () => {
      ws.close();
    };
  }, []);

  const sendMessage = () => {
    if (socket && input.trim() !== "") {
      socket.send(input);
      setMessages((msgs) => [...msgs, `Sent: ${input}`]);
      setInput("");
    }
  };

  return (
    <div style={{ padding: "1rem" }}>
      <h2 style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>WebSocket Client</h2>
      <div style={{ marginBottom: "0.5rem" }}>
        <strong>Status:</strong> {status}
      </div>
      <div
        style={{
          border: "1px solid #ccc",
          padding: "0.5rem",
          marginBottom: "0.5rem",
          height: "200px",
          overflowY: "scroll",
          backgroundColor: "#f9f9f9",
          whiteSpace: "pre-wrap",
          fontFamily: "monospace",
          fontSize: "0.9rem",
        }}
      >
        {messages.map((msg, idx) => (
          <div key={idx}>{msg}</div>
        ))}
      </div>
      <input
        type="text"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        placeholder="Type a message"
        style={{ padding: "0.25rem", marginRight: "0.5rem", width: "70%" }}
      />
      <button
        onClick={sendMessage}
        style={{
          padding: "0.25rem 0.5rem",
          backgroundColor: "#3b82f6",
          color: "white",
          border: "none",
          borderRadius: "0.25rem",
        }}
      >
        Send
      </button>
    </div>
  );
};

export default WebSocketClient;
