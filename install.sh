#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BIN="${PREFIX:-$HOME/.local}/bin"

mkdir -p "$BIN"

cat > "$BIN/tunnelr" <<EOF
#!/usr/bin/env bash
exec python3 "$ROOT/tunnelr.py" "\$@"
EOF

chmod +x "$BIN/tunnelr"

echo "TunnelR installed to: $BIN/tunnelr"
echo
echo "Try:"
echo "  tunnelr localhost:3000"
