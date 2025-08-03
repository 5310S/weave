# Weave

An experimental peer-to-peer dating application prototype. This repository
contains a Swift Package that will eventually power the networking layer for an
iOS client. The current prototype includes:

- Basic `Peer` model storing network, location and last-seen timestamp information.
- `PeerManager` with rudimentary radius-based filtering, optional attribute-based matching, and nearest-peer queries using the Haversine formula.
- `PeerManager` supports peer removal, updates to network address, location and attribute metadata, and pruning of stale peers by last-seen time.
- `PeerManager` can rank nearby peers by shared attribute matches.
- `PeerStore` persists known peers to disk and restores them on launch.
- Sample command-line entry point demonstrating peer filtering, updates and pruning.
- Unit tests covering radius-based, proximity-sorted, attribute-filtered, matching, update and pruning logic.

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
