# Weave

An experimental peer-to-peer dating application prototype. This repository
contains a Swift Package that will eventually power the networking layer for an
iOS client. The current prototype includes:


- Basic `Peer` model storing a display name, network details, location and last-seen timestamp information.
- `PeerManager` with rudimentary radius-based filtering, geohash prefix queries (with optional attribute filters), optional attribute-based matching, and nearest-peer queries (with optional attribute filters) using the Haversine formula.

- `PeerManager` supports peer removal, updates to display name, network address, location and attribute metadata (including individual attribute changes), pruning of stale peers by last-seen time, and blocking/unblocking of peers.
- `PeerManager` can rank nearby peers by shared attribute matches.
- `PeerManager` provides a `connect(to:)` helper that refreshes last-seen timestamps while respecting block lists.
- `PeerManager` can list the most recently seen peers for recency-based discovery.
- `PeerManager` supports liking and unliking peers and retrieving liked peers.
- `PeerManager` can determine mutual matches by returning liked peers whose attributes
  indicate they like the current user.
- `PeerStore` persists known peers, blocked IDs, and liked peers to disk and restores them on launch.

- Sample command-line entry point demonstrating peer filtering, geohash prefix queries (with attribute filters), nearest-peer querying, updates (including display name and attribute tweaks), blocking, liking and pruning.

- Unit tests covering radius-based, proximity-sorted, attribute-filtered, matching, update, blocking and pruning logic.

## Technology Stack

| Area | Technologies | Purpose |
|------|--------------|---------|
| Programming Language & UI | Swift + SwiftUI | Native iOS development with a modern declarative interface. |
| P2P Networking | libp2p (Kademlia DHT) | Serverless peer discovery and secure transport across the internet. |
| NAT Traversal | UDP hole punching, UPnP / NAT-PMP | Enables peers behind home routers to reach each other directly. |
| Geolocation | CoreLocation | Retrieves user coordinates for radius-based filtering. |
| Local Discovery | mDNS / Bonjour (optional) | Finds nearby peers on the same network when offline. |
| Persistence | CoreData or SQLite | Stores profiles, preferences and chat history on-device. |
| Encryption | CryptoKit or libsodium | Provides end-to-end encryption for sensitive data and messages. |
| Notifications | APNs (optional) | Alerts users about messages or connection requests when backgrounded. |


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

