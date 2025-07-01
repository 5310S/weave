/* eslint-disable no-restricted-globals */

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

declare const sha3_256: { (message: string): string };

self.onmessage = async (e: MessageEvent<BlockTemplate>) => {
    const { index, previous_hash, data, difficulty, timestamp } = e.data;
    const prefix = '0'.repeat(difficulty);
    let nonce = 0;

    while (true) {
        const input = `${index}${timestamp}${data}${previous_hash}${nonce}`;
        const hash = sha3_256(input);
        if (hash.startsWith(prefix)) {
            self.postMessage({
                index,
                timestamp,
                data,
                previous_hash,
                hash,
                nonce
            } as Block);
            break;
        }
        nonce++;
        // Yield to prevent blocking
        await new Promise(resolve => setTimeout(resolve, 0));
    }
};

export {};