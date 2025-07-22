import React from 'react';
import './App.scss';



const App: React.FC = () => {
    // const [status, setStatus] = useState<string>('Connecting to node...');
    // const [blockCount, setBlockCount] = useState<number>(0);

    return (
        <div className="app-container">
            <h1 className="app-title">Smartphone Crypto Miner</h1>
            {/* <Miner
                nodeUrl="ws://your-node-ip:3000/ws"
                onStatusChange={setStatus}
                onBlockMined={() => setBlockCount(count => count + 1)}
            /> */}

        
            <div className="status-container">
                {/* <p className="status-text">Status: {status}</p> */}
                {/* <p className="block-count">Blocks Mined: {blockCount}</p> */}
            </div>
        </div>
    );
};

export default App;