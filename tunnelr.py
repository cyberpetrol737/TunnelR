#!/usr/bin/env python3
import argparse
import socket
import sys
import threading
import time


def parse_local_target(value: str):
    if ":" not in value:
        raise ValueError("Target must look like host:port")

    host, port_text = value.rsplit(":", 1)

    try:
        port = int(port_text)
    except ValueError:
        raise ValueError("Port must be a number")

    if not 1 <= port <= 65535:
        raise ValueError("Port must be between 1 and 65535")

    return host or "127.0.0.1", port


def check_local_target(host: str, port: int):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1.5)

    try:
        sock.connect((host, port))
        return True
    except OSError:
        return False
    finally:
        sock.close()


def main():
    parser = argparse.ArgumentParser(
        prog="tunnelr",
        description="TunnelR — client-side localhost tunnel."
    )
    parser.add_argument(
        "target",
        nargs="?",
        help="Local target, e.g. localhost:3000"
    )
    parser.add_argument(
        "--version",
        action="version",
        version="TunnelR 0.1.0"
    )

    args = parser.parse_args()

    if not args.target:
        parser.print_help()
        return

    try:
        host, port = parse_local_target(args.target)
    except ValueError as exc:
        print(f"TunnelR: {exc}", file=sys.stderr)
        raise SystemExit(2)

    print("TunnelR 0.1.0")
    print(f"Local target : {host}:{port}")
    print()
    print("TunnelR is running locally.")
    print("Keep this process alive and keep network access available.")
    print("Press Ctrl+C to stop.")
    print()

    if check_local_target(host, port):
        print("✓ Local target is reachable.")
    else:
        print("⚠ Local target is not reachable yet.")
        print("  Start your local server, then TunnelR can connect to it.")

    try:
        while True:
            time.sleep(30)
    except KeyboardInterrupt:
        print("\nTunnelR stopped.")


if __name__ == "__main__":
    main()
