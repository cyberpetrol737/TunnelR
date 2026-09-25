# TunnelR

TunnelR is a client-side localhost tunneling tool designed to run entirely on the user's own device.

## Architecture

TunnelR does **not** run a TunnelR-owned server.

```text
Internet / peer
      │
      ▼
Tunnel connection
      │
      ▼
User's phone / laptop / PC
      │
      ▼
localhost:<port>
```

The user's device keeps the tunnel alive. As long as TunnelR remains running in the terminal/background and the device has a stable network connection, the tunnel can remain available.

## Status

This repository contains the initial project structure and a transport abstraction. The actual public transport/backend can be implemented without making TunnelR itself a hosted server.

## Usage

```bash
python3 -m src.tunnelr --help
```

TunnelR is intended for development and self-hosting workflows. Do not expose private services without appropriate authentication.
