# Weave

An experimental peer-to-peer dating application prototype. This repository
contains a Swift Package that will eventually power the networking layer for an
iOS client. The current prototype includes:

- Basic `Peer` model storing network, location and last-seen timestamp information.
- `PeerManager` with rudimentary radius-based filtering, optional attribute-based matching, and nearest-peer queries (with optional attribute filters) using the Haversine formula.
- `PeerManager` supports peer removal, updates to network address, location and attribute metadata (including individual attribute changes), pruning of stale peers by last-seen time, and blocking/unblocking of peers.
- `PeerManager` can rank nearby peers by shared attribute matches.
- `PeerManager` provides a `connect(to:)` helper that refreshes last-seen timestamps while respecting block lists.
- `PeerStore` persists known peers and blocked IDs to disk and restores them on launch.
- Sample command-line entry point demonstrating peer filtering, geohash prefix queries, nearest-peer querying, updates (including attribute tweaks), blocking and pruning.
- Unit tests covering radius-based, proximity-sorted, attribute-filtered, matching, update, blocking and pruning logic.

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
- Use geohash bucketing to index peers in a distributed hash table for efficient location-based lookups.
