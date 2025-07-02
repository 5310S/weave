import { useEffect, useState } from "react";

const WebSocketClient: React.FC = () => {
  const [socket, setSocket] = useState<WebSocket | null>(null);
  const [messages, setMessages] = useState<string[]>([]);
  const [input, setInput] = useState<string>("");

  useEffect(() => {
    const ws = new WebSocket("ws://82.25.86.57:8080");
    setSocket(ws);

    ws.onopen = () => {
      console.log("WebSocket connected");
    };

    ws.onmessage = (event: MessageEvent) => {
      console.log("Received:", event.data);
      setMessages((prev) => [...prev, event.data]);
    };

    ws.onclose = () => {
      console.log("WebSocket closed");
    };

    ws.onerror = (err) => {
      console.error("WebSocket error:", err);
    };

    return () => {
      ws.close();
    };
  }, []);

  const sendMessage = () => {
    if (socket && input.trim() !== "") {
      socket.send(input);
      setInput("");
    }
  };

  return (
    <div style={{ padding: "1rem" }}>
      <h2 style={{ fontSize: "1.25rem", fontWeight: "bold", marginBottom: "0.5rem" }}>
        WebSocket Client
      </h2>
      <div
        style={{
          border: "1px solid #ccc",
          padding: "0.5rem",
          marginBottom: "0.5rem",
          height: "200px",
          overflowY: "scroll",
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
        style={{ border: "1px solid #ccc", padding: "0.25rem", marginRight: "0.5rem" }}
        placeholder="Type a message"
      />
      <button
        onClick={sendMessage}
        style={{
          backgroundColor: "#3b82f6",
          color: "white",
          padding: "0.25rem 0.5rem",
          borderRadius: "0.25rem",
          border: "none",
        }}
      >
        Send
      </button>
    </div>
  );
};

export default WebSocketClient;
