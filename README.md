# Weave

An experimental peer-to-peer dating application prototype. This repository
contains a Swift Package that will eventually power the networking layer for an
iOS client. The current prototype includes:

- Basic `Peer` model storing network and location information.
- `PeerManager` with rudimentary radius-based filtering and nearest-peer queries using the Haversine formula.
- Sample command-line entry point demonstrating peer filtering.
- Unit tests covering radius-based and proximity-sorted peer discovery logic.

## Building

```bash
swift build
```

## Testing

```bash
swift test
```

## Next Steps

- Integrate [libp2p](https://libp2p.io) for decentralised peer discovery and messaging.
- Add geolocation fetching via CoreLocation on iOS.
- Implement encrypted communication using CryptoKit.
