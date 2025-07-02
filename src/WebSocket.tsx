import { useEffect, useState } from "react";

const WebSocketClient: React.FC = () => {
  const [socket, setSocket] = useState<WebSocket | null>(null);
  const [messages, setMessages] = useState<string[]>([]);
  const [input, setInput] = useState<string>("");
  const [status, setStatus] = useState<string>("Connecting...");

  const addDebug = (msg: string) => {
    const timestamp = new Date().toLocaleTimeString();
    setMessages((prev) => [...prev, `[${timestamp}] ${msg}`]);
  };

  useEffect(() => {
    const ws = new WebSocket("wss://82.25.86.57:8081");
    setSocket(ws);

    ws.onopen = () => {
      setStatus("WebSocket connected");
      addDebug("WebSocket onopen event fired");
    };

    ws.onmessage = (event: MessageEvent) => {
      addDebug(`onmessage: ${event.data}`);
    };

    ws.onclose = (event: CloseEvent) => {
      setStatus(`WebSocket closed (code: ${event.code}, reason: ${event.reason})`);
      addDebug(`onclose event fired: code=${event.code}, reason=${event.reason}`);
    };

    ws.onerror = (event) => {
      setStatus("WebSocket error");
      addDebug(`onerror event fired: ${JSON.stringify(event)}`);
      addDebug(`readyState: ${ws.readyState}`);
    };

    return () => {
      ws.close();
      addDebug("WebSocket manually closed on unmount");
    };
  }, []);

  const sendMessage = () => {
    if (socket && input.trim() !== "") {
      socket.send(input);
      addDebug(`Sent: ${input}`);
      setInput("");
    }
  };

  return (
    <div style={{ padding: "1rem" }}>
      <h2 style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>WebSocket Client Debugger</h2>
      <div style={{ marginBottom: "0.5rem" }}>
        <strong>Status:</strong> {status}
      </div>
      <div
        style={{
          border: "1px solid #ccc",
          padding: "0.5rem",
          marginBottom: "0.5rem",
          height: "300px",
          overflowY: "scroll",
          backgroundColor: "#f9f9f9",
          whiteSpace: "pre-wrap",
          fontFamily: "monospace",
          fontSize: "0.8rem",
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
