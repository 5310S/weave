import React, { useState, useEffect } from 'react';

interface Message {
  id: number;
  text: string;
  timestamp: string;
}

const ChatBox: React.FC = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState<string>('');
  const [ws, setWs] = useState<WebSocket | null>(null);

  // Initialize WebSocket connection
  useEffect(() => {
    const websocket = new WebSocket('ws://localhost:8080');
    setWs(websocket);

    // Handle incoming messages
    websocket.onmessage = (event) => {
      const receivedData = JSON.parse(event.data);
      const message: Message = {
        id: messages.length + 1,
        text: receivedData.text,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages((prev) => [...prev, message]);
    };

    // Handle connection open
    websocket.onopen = () => {
      console.log('Connected to WebSocket server');
    };

    // Handle errors
    websocket.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    // Handle connection close
    websocket.onclose = () => {
      console.log('Disconnected from WebSocket server');
    };

    // Cleanup on component unmount
    return () => {
      websocket.close();
    };
  }, [messages.length]); // Note: Including messages.length to ensure message ID increments correctly

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !ws) return;

    // Send message to WebSocket server
    const messageData = { text: newMessage };
    ws.send(JSON.stringify(messageData));

    // Add message to local state (optional, if you want to show sent messages immediately)
    const message: Message = {
      id: messages.length + 1,
      text: newMessage,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };
    setMessages([...messages, message]);
    setNewMessage('');
  };

  return (
    <div className="flex flex-col h-[500px] w-full max-w-md mx-auto border rounded-lg shadow-lg bg-white">
      <div className="flex-1 p-4 overflow-y-auto">
        {messages.length === 0 ? (
          <p className="text-gray-500 text-center">No messages yet</p>
        ) : (
          messages.map((message) => (
            <div key={message.id} className="mb-2 p-2 bg-blue-100 rounded-lg">
              <p className="text-sm">{message.text}</p>
              <p className="text-xs text-gray-500">{message.timestamp}</p>
            </div>
          ))
        )}
      </div>
      <div className="border-t p-4">
        <form onSubmit={handleSendMessage} className="flex gap-2">
          <input
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Type a message..."
            className="flex-1 p-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600"
            disabled={!ws || ws.readyState !== WebSocket.OPEN}
          >
            Send
          </button>
        </form>
      </div>
    </div>
  );
};

export default ChatBox;