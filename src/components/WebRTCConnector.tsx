import React, { useState, useEffect, useCallback } from 'react';

interface WebRTCConnectorProps {
  signalingUrl?: string;
}

const WebRTCConnector: React.FC<WebRTCConnectorProps> = ({ signalingUrl = 'ws://82.25.86.57:8081' }) => {
  const [peerConnection, setPeerConnection] = useState<RTCPeerConnection | null>(null);
  const [dataChannel, setDataChannel] = useState<RTCDataChannel | null>(null);
  const [messages, setMessages] = useState<string[]>([]);
  const [connectionStatus, setConnectionStatus] = useState<string>('Disconnected');
  const [error, setError] = useState<string | null>(null);

  const initPeerConnection = useCallback((websocket: WebSocket) => {
    const config: RTCConfiguration = {
      iceServers: [{ urls: 'stun:stun.l.google.com:19302' }],
    };
    const pc = new RTCPeerConnection(config);
    setPeerConnection(pc);

    // Handle ICE candidates
    pc.onicecandidate = (event: RTCPeerConnectionIceEvent) => {
      if (event.candidate) {
        console.log('Sending ICE candidate:', event.candidate);
        websocket.send(JSON.stringify({
          type: 'Candidate',
          candidate: event.candidate.toJSON(),
        }));
      }
    };

    // Handle connection state changes
    pc.onconnectionstatechange = () => {
      console.log('Connection state:', pc.connectionState);
      setConnectionStatus(pc.connectionState);
    };

    // Create data channel (if server creates it, use ondatachannel instead)
    const dc = pc.createDataChannel('mining');
    setDataChannel(dc);

    dc.onopen = () => {
      console.log('Data channel opened');
      // Example: Send a GET_WORK message
      dc.send(JSON.stringify({ type: 'GET_WORK' }));
    };

    dc.onmessage = (event: MessageEvent) => {
      console.log('Received message:', event.data);
      setMessages((prev) => [...prev, event.data as string]);
    };

    dc.onclose = () => {
      console.log('Data channel closed');
    };

    dc.onerror = (error: Event) => {
      console.error('Data channel error:', error);
      setError('Data channel failure—check network or protocol mismatch');
    };

    // Alternatively, if server creates the channel:
    // pc.ondatachannel = (event: RTCDataChannelEvent) => {
    //   const dc = event.channel;
    //   setDataChannel(dc);
    //   // Set up onopen, onmessage, etc.
    // };

    // Create offer and send it
    pc.createOffer()
      .then((offer: RTCSessionDescriptionInit) => {
        return pc.setLocalDescription(offer);
      })
      .then(() => {
        console.log('Sending offer');
        websocket.send(JSON.stringify({
          type: 'Offer',
          sdp: pc.localDescription?.sdp,
          offerType: pc.localDescription?.type, // Note: Adjust based on Signal enum; use 'offer' for type
        }));
      })
      .catch((error: any) => {
        console.error('Error creating offer:', error);
        setError(`Offer creation failed: ${error.message}`);
      });
  }, []);

  const handleSignal = useCallback((signal: any) => {
    if (!peerConnection) return;

    if (signal.type === 'Answer') {
      console.log('Setting remote description (answer)');
      const desc = new RTCSessionDescription({
        type: 'answer',
        sdp: signal.sdp, // Adjust based on your Signal structure
      });
      peerConnection.setRemoteDescription(desc)
        .catch((error: any) => {
          console.error('Error setting remote description:', error);
          setError(`Remote description failed: ${error.message}`);
        });
    } else if (signal.type === 'Candidate') {
      console.log('Adding ICE candidate');
      peerConnection.addIceCandidate(signal.candidate)
        .catch((error: any) => {
          console.error('Error adding ICE candidate:', error);
          setError(`ICE candidate addition failed: ${error.message}`);
        });
    }
  }, [peerConnection]);

  useEffect(() => {
    // Set up WebSocket for signaling
    const websocket = new WebSocket(signalingUrl);

    websocket.onopen = () => {
      console.log('WebSocket connected');
      setError(null);
      initPeerConnection(websocket);
    };

    websocket.onmessage = (event: MessageEvent) => {
      const signal = JSON.parse(event.data) as any; // Adjust type based on Signal enum
      console.log('Received signal:', signal);
      handleSignal(signal);
    };

    websocket.onclose = (event: CloseEvent) => {
      console.log('WebSocket closed:', event.reason);
      setConnectionStatus('Disconnected');
      setError(event.reason || 'Connection closed unexpectedly');
    };

    websocket.onerror = (error: Event) => {
      console.error('WebSocket error:', error);
      setError('WebSocket connection failed—check server, IP/port, and firewall');
    };

    return () => {
      if (peerConnection) {
        peerConnection.close();
      }
      websocket.close();
    };
  }, [signalingUrl, initPeerConnection, handleSignal]);

  const sendMessage = (msg: any) => {
    if (dataChannel && dataChannel.readyState === 'open') {
      dataChannel.send(JSON.stringify(msg));
      console.log('Sent message:', msg);
    } else {
      console.warn('Data channel not open');
      setError('Cannot send—data channel not open');
    }
  };

  return (
    <div>
      <h2>WebRTC Connection Status: {connectionStatus}</h2>
      {error && <p style={{ color: 'red' }}>Error: {error}</p>}
      <button onClick={() => sendMessage({ type: 'GET_WORK' })}>Get Work</button>
      <button onClick={() => sendMessage({ type: 'SUBMIT_SHARE', payload: { nonce: '12345' } })}>Submit Share</button>
      <ul>
        {messages.map((msg, index) => (
          <li key={index}>{msg}</li>
        ))}
      </ul>
    </div>
  );
};

export default WebRTCConnector;