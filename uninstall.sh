#!/usr/bin/env bash
set -euo pipefail

TARGET="${PREFIX:-$HOME/.local}/bin/tunnelr"

if [ -f "$TARGET" ]; then
    rm "$TARGET"
    echo "Removed $TARGET"
else
    echo "TunnelR is not installed at $TARGET"
fi
