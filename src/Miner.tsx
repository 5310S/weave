import React, { useEffect, useRef } from 'react';

interface BlockTemplate {
    index: number;
    previous_hash: string;
    data: string;
    difficulty: number;
    timestamp: number;
}

interface Block extends BlockTemplate {
    hash: string;
    nonce: number;
}

interface MinerProps {
    nodeUrl: string;
    onStatusChange: (status: string) => void;
    onBlockMined: () => void;
}

const Miner: React.FC<MinerProps> = ({ nodeUrl, onStatusChange, onBlockMined }) => {
    const wsRef = useRef<WebSocket | null>(null);
    const workerRef = useRef<Worker | null>(null);

    useEffect(() => {
        // Initialize WebSocket
        wsRef.current = new WebSocket(nodeUrl);
        wsRef.current.onopen = () => {
            onStatusChange('Connected to node');
        };
        wsRef.current.onmessage = (event: MessageEvent) => {
            const message = event.data as string;
            if (message === 'Block accepted') {
                onStatusChange('Block accepted!');
                onBlockMined();
                return;
            }
            if (message.startsWith('Error')) {
                onStatusChange(message);
                return;
            }
            try {
                const template: BlockTemplate = JSON.parse(message);
                if (workerRef.current) {
                    workerRef.current.postMessage(template);
                    onStatusChange('Mining block...');
                }
            } catch (e) {
                onStatusChange('Error parsing template');
            }
        };
        wsRef.current.onerror = () => {
            onStatusChange('WebSocket error');
        };
        wsRef.current.onclose = () => {
            onStatusChange('Disconnected from node');
        };

        // Initialize Web Worker
        workerRef.current = new Worker(new URL('./Worker.ts', import.meta.url));
        workerRef.current.onmessage = (e: MessageEvent<Block>) => {
            if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
                wsRef.current.send(JSON.stringify(e.data));
            }
        };

        // Handle visibility to pause mining
        const handleVisibilityChange = () => {
            if (document.hidden) {
                if (workerRef.current) {
                    workerRef.current.terminate();
                    workerRef.current = new Worker(new URL('./Worker.ts', import.meta.url));
                    onStatusChange('Mining paused (app hidden)');
                }
            } else {
                onStatusChange('Resuming mining...');
            }
        };
        document.addEventListener('visibilitychange', handleVisibilityChange);

        // Cleanup
        return () => {
            if (wsRef.current) {
                wsRef.current.close();
            }
            if (workerRef.current) {
                workerRef.current.terminate();
            }
            document.removeEventListener('visibilitychange', handleVisibilityChange);
        };
    }, [nodeUrl, onStatusChange, onBlockMined]);

    return null; // No UI, just logic
};

export default Miner;