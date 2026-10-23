# TunnelR

Expose a web server running on your computer (or phone) at a public HTTPS address, through a relay **you** run.

```
 visitor ──HTTPS──▶  relay (public server)  ◀══ one outbound wss:// connection ══  tunnelr  ──▶  http://localhost:3000
                     https://<name>.tunnel.example.com                              (your machine)
```

- **Real architecture, no pretending.** A public tunnel needs a reachable server. TunnelR ships both halves: the
  `tunnelr start` client and the `tunnelr relay` server. You deploy the relay once (a small VPS and a domain are enough);
  see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).
- **Zero dependencies.** Plain Node.js 20+ (built-in `http`, `net`, `tls`, `crypto`). Nothing to `npm install`, which also makes
  it practical on Android (Termux) and small servers. It includes its own strict WebSocket implementation.
- **Secure by default.** Token authentication (only hashes stored on the relay), encrypted transport required off-loopback,
  SSRF-safe target rules, strict request validation, size/rate/concurrency limits, a loopback-only token-protected dashboard.
- **Foreground process.** The tunnel lives exactly as long as `tunnelr start` runs. Ctrl+C (or `tunnelr stop`) closes it cleanly.

> **Status.** Everything is verified end to end on loopback with 119 automated tests (see [docs/FEATURE_STATUS.md](docs/FEATURE_STATUS.md)).
> Tunnelling over the real internet has **not** been tested here, because the build environment had no network access.
> Treat the first deployment on your own domain as the final acceptance test (checklist in the deployment guide).

## Contents

[Quick start](#quick-start) · [Install](#install) · [Commands](#commands) · [Configuration](#configuration) · [Dashboard](#dashboard) ·
[How requests are handled](#how-requests-are-handled) · [Security](#security) · [Troubleshooting](#troubleshooting) ·
[Development](#development) · [Limitations](#limitations) · [License](#license)

## Quick start

### A. Try it on one machine (no domain needed)

```bash
npm run demo               # starts an app, a relay and a client, sends one request through the tunnel, exits
npm run demo -- --keep     # same, but keeps running so you can open the printed URL in a browser
```

The same thing by hand, in three terminals (`localhost` tunnels use `*.localhost`, which browsers resolve to your own machine):

```bash
# 1. make a token; it prints the secret AND the entry for the relay
node bin/tunnelr.js token create --name me
#    -> copy the "tr_..." token and the "me:<hash>" entry

# 2. relay (terminal 1)
TUNNELR_RELAY_TOKENS='me:<hash>' node bin/tunnelr.js relay \
  --domain localhost --public-scheme http --public-port 8080 --port 8080

# 3. your app (terminal 2) - anything, for example:
python3 -m http.server 3000

# 4. the tunnel (terminal 3)
TUNNELR_TOKEN='tr_...' node bin/tunnelr.js start --port 3000 --relay ws://localhost:8080
#    -> prints  http://<random>.localhost:8080   - open it
```

### B. A real public tunnel

1. Deploy the relay on a server with a domain and wildcard DNS/TLS - [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) (about 15 minutes).
2. On the server: `tunnelr token create --name alice`, add the printed `alice:<hash>` entry to the relay's `TUNNELR_RELAY_TOKENS`, send Alice her token.
3. On your machine:

```bash
export TUNNELR_RELAY=wss://tunnel.example.com
export TUNNELR_TOKEN=tr_...            # from step 2
tunnelr start --port 3000              # or: tunnelr start --url http://localhost:3000
```

```
✔ Tunnel ready

  Public URL    https://k3x9q2m7ab.tunnel.example.com
  Forwarding    https://k3x9q2m7ab.tunnel.example.com -> http://localhost:3000
  Dashboard     http://127.0.0.1:4040/#<login token>
  Visitor auth  off - anyone with the URL can reach your app

Press Ctrl+C to stop (or run "tunnelr stop" from another terminal).
```

The URL is printed only after the relay has confirmed the tunnel. Run `tunnelr start` with no `--port` in a terminal and it asks which local URL to expose.

## Install

```bash
unzip TunnelR.zip && cd TunnelR        # or: git clone <your repository> && cd TunnelR
node bin/tunnelr.js --help             # works immediately: there is nothing to install
npm link                               # optional: puts a "tunnelr" command on your PATH (or: npm install -g .)
```

Requires **Node.js 20 or newer** on Linux, macOS or Android/Termux (`pkg install nodejs`). The relay additionally needs a public
host and a domain. State (running tunnels, optional per-user config) lives in `~/.tunnelr` (`$TUNNELR_HOME`).

## Commands

Exit codes: `0` success · `1` runtime error · `2` usage or configuration error · `3` nothing running (`status`, `dashboard`).

### `tunnelr start` - open a tunnel

`tunnelr start [--port <n> | --url <url>] [options]`

| Option | Meaning |
| --- | --- |
| `--port <n>`, `-p` | Local port to expose (same as `--url http://localhost:<n>`). |
| `--url <url>`, `-u` | Local URL to expose (`TUNNELR_TARGET`). Only scheme, host and port; loopback targets by default. |
| `--relay <url>`, `-r` | Relay URL such as `wss://tunnel.example.com` (`TUNNELR_RELAY`). `ws://` only for loopback. |
| `--token-file <file>` | Read the access token from a file (`TUNNELR_TOKEN_FILE`). The token is never a command-line flag. |
| `--subdomain <name>`, `-s` | Ask for a fixed name (3-32 chars, `a-z 0-9 -`). Refused if another token owns it. |
| `--host-header <mode>` | `rewrite` (default) sends your app its own `localhost:3000` host; `preserve` forwards the public host. |
| `--allow-private` | Also allow targets on private networks (LAN, Docker). Cloud-metadata ranges stay blocked. |
| `--insecure-target` | Skip certificate verification for an `https://` target (self-signed local certificates). |
| `--relay-ca <file>` | Trust an extra CA certificate (PEM) for the relay - private CA or self-signed relay. |
| `--insecure-relay` | Allow unencrypted `ws://` to a non-local relay. **Your token travels in clear text.** |
| `--dashboard`, `--no-dashboard` | Serve the local web dashboard (default on). The control API stays available for `status`/`stop`. |
| `--dashboard-port <n>` | Dashboard port on `127.0.0.1` (default 4040; busy ports fall back to a free one; `0` = any). |
| `--timeout <sec>` | How long to wait for your local app to start answering (default 30). |
| `--quiet`, `-q` | Do not print a line per request. |
| `--json` | Machine-readable JSON lines (`ready`, `request`, `warning`, `error`, `stopped`). |
| `--log-level <level>` | `debug`, `info`, `warn`, `error` or `silent` (`TUNNELR_LOG_LEVEL`). |
| `--color`, `--no-color` | Force colours on or off (also honours `NO_COLOR`). |
| `--config <file>` | Read settings from a JSON file. |
| `--env-file <file>` | Load `TUNNELR_*` settings from a `.env` file. |

Visitor password: `TUNNELR_BASIC_AUTH=user:password tunnelr start -p 3000` makes the **relay** demand HTTP basic auth before any
request reaches your machine (set via environment or config file only, so it never shows up in `ps`).

### `tunnelr status` - what is running here

`tunnelr status [--json] [--no-color]` lists every tunnel on this machine: id, state, public URL, target, traffic. Exit code `3` if none.

### `tunnelr stop` - close a tunnel

`tunnelr stop [id] [--all] [--force] [--no-color]` asks the process to close its tunnel and exit (graceful, over its loopback
control API). With one tunnel running no id is needed; `--all` stops everything; `--force` falls back to `SIGTERM` only when the
control API does not answer.

### `tunnelr dashboard` - dashboard link

`tunnelr dashboard [id]` prints `http://127.0.0.1:<port>/#<token>`. Open it in any browser on the same machine
(Termux: `termux-open-url "$(tunnelr dashboard)"`). The token is a per-run secret - treat the link like a password.

### `tunnelr relay` - run the public side

`tunnelr relay --domain <domain> [options]` - needs wildcard DNS and TLS; see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

| Option | Meaning |
| --- | --- |
| `--domain <domain>` | Base domain; tunnels live at `<name>.<domain>` (`TUNNELR_DOMAIN`). Required. |
| `--host <addr>` | Address to bind. Default `127.0.0.1`. A public bind needs TLS or a trusted proxy (see below). |
| `--port <n>`, `-p` | Listening port (default 8080). |
| `--public-scheme <scheme>` | `https` (default) or `http`: the scheme in the URLs handed to clients. |
| `--public-port <n\|auto>` | Port shown in public URLs; omit for 80/443; `auto` = the listening port (local testing). |
| `--tls-cert <file>`, `--tls-key <file>` | Terminate TLS in this process (wildcard certificate, PEM). |
| `--trust-proxy <n>` | Number of trusted reverse-proxy hops in front (use `1` behind Caddy/nginx). Enables `X-Forwarded-For`. |
| `--tokens-file <file>` | JSON file with token hashes; re-read on `SIGHUP`. |
| `--max-tunnels-per-token <n>` | Concurrent tunnels per token (default 3). |
| `--max-body-mb <mb>` | Largest request body in MiB (default 100). |
| `--rate-limit <n>` | Requests per second per tunnel, `0` = unlimited (default 100, burst 2x). |
| `--reservation-ttl <sec>` | How long a disconnected tunnel keeps its name for its owner (default 300). |
| `--max-tunnel-age <sec>` | Force tunnels to reconnect (re-authenticate) after this long; `0` = never (default). |
| `--access-log` | Log one line per proxied request (path only - query strings are never logged). |
| `--insecure-http` | Allow a public bind without TLS or proxy. **Tokens would travel in clear text.** |
| `--config <file>`, `--env-file <file>`, `--json`, `--log-level <level>`, `--color` | As for `start`. |

The relay refuses to start without tokens (it would be an open proxy) and refuses a non-loopback bind without TLS or
`--trust-proxy` (it would accept tokens in clear text) unless you pass `--insecure-http`.
`SIGHUP` reloads the tokens file and the TLS certificate without dropping tunnels (owners removed from the list are disconnected).

### `tunnelr token create` - make an access token

`tunnelr token create [--name <name>] [--admin]` prints a random 256-bit token (give it to its owner, shown once) and the
`name:hash` entry for the relay. The relay stores only the hash. `--admin` makes an administrator token (list and terminate any
tunnel through the relay API; it cannot open tunnels). To rotate a token, list the new hash under the same name next to the old one,
reload, then remove the old one.

## Configuration

Precedence, highest first: **command-line flags → environment variables → `.env` file (`TUNNELR_*` only, `./.env` or `--env-file`) → JSON config file → defaults.**
Secrets (token, visitor password) are accepted only from the environment, a token file or a `chmod 600` config file - never from flags.

Client environment: `TUNNELR_RELAY`, `TUNNELR_TOKEN`, `TUNNELR_TOKEN_FILE`, `TUNNELR_TARGET` / `TUNNELR_PORT`, `TUNNELR_SUBDOMAIN`,
`TUNNELR_BASIC_AUTH`, `TUNNELR_HOST_HEADER`, `TUNNELR_ALLOW_PRIVATE`, `TUNNELR_INSECURE_TARGET`, `TUNNELR_INSECURE_RELAY`,
`TUNNELR_RELAY_CA`, `TUNNELR_DASHBOARD_PORT`, `TUNNELR_TIMEOUT`, `TUNNELR_LOG_LEVEL`, `TUNNELR_LOG_FORMAT`, `TUNNELR_CONFIG`, `TUNNELR_HOME`.

Relay environment: `TUNNELR_DOMAIN`, `TUNNELR_RELAY_HOST`, `TUNNELR_RELAY_PORT`, `TUNNELR_PUBLIC_SCHEME`, `TUNNELR_PUBLIC_PORT`, `TUNNELR_TLS_CERT`,
`TUNNELR_TLS_KEY`, `TUNNELR_TRUST_PROXY`, `TUNNELR_RELAY_TOKENS`, `TUNNELR_RELAY_ADMIN_TOKENS`, `TUNNELR_TOKENS_FILE`,
`TUNNELR_MAX_TUNNELS_PER_TOKEN`, `TUNNELR_MAX_TUNNELS`, `TUNNELR_MAX_STREAMS_PER_TUNNEL`, `TUNNELR_MAX_WS_PER_TUNNEL`, `TUNNELR_MAX_BODY_MB`, `TUNNELR_RATE_LIMIT`, `TUNNELR_RESERVATION_TTL`,
`TUNNELR_MAX_TUNNEL_AGE`, `TUNNELR_ACCESS_LOG`, `TUNNELR_INSECURE_HTTP`.

[`.env.example`](.env.example) lists them with placeholders. Config files are JSON with the camelCase option names
(`./tunnelr.config.json` or `~/.tunnelr/config.json` for the client, `./tunnelr-relay.config.json` for the relay):

```json
{ "relay": "wss://tunnel.example.com", "token": "tr_...", "port": 3000, "subdomain": "myapp", "hostHeader": "rewrite" }
```

A warning is printed if a file holding a token is readable by other users (`chmod 600`).

Built-in defaults worth knowing: the client reconnects with exponential back-off (1 s doubling to 30 s, with jitter) and gives up
after 3 failed attempts only if it has never connected; heartbeat every 15 s (relay pings every 20 s); relay limits are 3 tunnels
per token, 64 concurrent requests and 32 WebSockets per tunnel, 100 req/s per tunnel, 100 MiB request bodies, 60 s to first response byte.

## Dashboard

`tunnelr start` serves a small dashboard on **127.0.0.1** only (default port 4040). It shows connection status, the target, the public
URL with a copy button, uptime, request counts and traffic, response-code distribution, recent requests (paths only), connection events
and configuration checks, and offers Reconnect, Pause/Resume, Stop, and validated edits of target, relay and subdomain. Data comes live from the running
client; nothing is sample data. The access token and the visitor password are never sent to the browser.

Protection: every API call needs a random per-run token; requests with a foreign `Host` header (DNS rebinding) or foreign `Origin` are refused;
the page is served with a strict Content-Security-Policy; all dynamic text is rendered as text. The login link (`/#<token>`) puts the token in
the URL fragment, which browsers never send to servers; the page moves it into session storage and clears the address bar.

## How requests are handled

- **One persistent connection.** The client dials the relay over `wss://` and registers; the relay answers with the public URL. Visitor
  requests are multiplexed over that connection with per-stream credit-based flow control, so a slow visitor slows your app instead of filling memory.
  Request and response bodies stream (nothing is buffered whole).
- **Fidelity.** Method, path, query string, headers (duplicates and case preserved, hop-by-hop headers removed), bodies, status codes, redirects,
  multiple `Set-Cookie`, content encodings and WebSocket upgrades (text/binary, close codes) pass through. The relay adds `X-Forwarded-For/Proto/Host` itself
  and ignores any the visitor sent.
- **Host header.** By default your app sees `Host: localhost:3000` (dev servers such as Vite or Django reject unknown hosts) and redirects to
  `http://localhost:3000/...` are rewritten to the public URL. Use `--host-header preserve` if your app builds URLs from the public host.
- **Cookies.** `Domain=` attributes are stripped from `Set-Cookie` so one tunnel cannot plant cookies for its siblings.
- **Errors.** If your app is down, visitors get a generic `502` page (no addresses or error text leak) and you get the real reason in the
  terminal and dashboard (`connection refused by localhost:3000 - is your local server running?`). Hung apps produce `504`.
  Relay-generated pages carry an `X-Tunnelr-Error` header so they are distinguishable from your own responses.
- **Reconnects.** If the connection drops (network change, relay restart) the client reconnects with back-off and gets the same URL back; names
  stay reserved for their owner for 5 minutes. In-flight requests at the moment of the drop fail; new ones work after the reconnect.

## Security

Read [docs/SECURITY.md](docs/SECURITY.md) for the full model. The short version:

- **Exposing a development server to the internet is dangerous.** Debug consoles (Flask/Werkzeug debugger, Django debug pages, Rails console, Jupyter,
  Node inspectors), admin panels, `.env` files, `.git` folders, databases UIs and anything that trusts "localhost" become reachable by everyone who has the URL.
  A random subdomain is **not** authentication. Use `TUNNELR_BASIC_AUTH`, stop the tunnel when you are done, and never tunnel services that hold real data without their own login.
- The **relay operator can read and modify all tunnelled traffic**: TLS ends at the relay. Only use a relay you control or trust.
- TunnelR only forwards to the one target you configured - loopback by default; link-local/cloud-metadata ranges are blocked even with `--allow-private`;
  host names are re-resolved and re-checked at connect time (DNS rebinding).
- If your local service has its own authentication it keeps working; TunnelR does not bypass it.

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| `no relay configured` / `no access token` | Set `TUNNELR_RELAY` and `TUNNELR_TOKEN` (or `--relay`, `--token-file`). |
| `the relay rejected the access token (HTTP 401)` | Wrong or revoked token, or the relay was started without your hash. Check the `name:hash` entry matches `tunnelr token create` output. |
| `refusing unencrypted ws:// to non-local relay` | Use `wss://`. Only for a throwaway test over a trusted network, add `--insecure-relay`. |
| `TLS verification of the relay failed` | Certificate does not match the domain, expired, or is from a private CA: fix the certificate or pass `--relay-ca ca.pem`. |
| `cannot reach the relay (ENOTFOUND / ECONNREFUSED)` | DNS or firewall: is the relay running and port 443 open? The client gives up after 3 attempts on first connect. |
| `does not look like a TunnelR relay (HTTP 404)` | The relay URL points at another web server (or a proxy that does not forward `/_tunnelr/connect` with WebSocket upgrades). |
| `subdomain_taken` / `forbidden_subdomain` | Another token owns the name (reserved 5 min after it disconnects), or your token is limited to certain names. |
| `too_many_tunnels` | The token's tunnel limit is reached; stale connections clear within about a minute, or raise `--max-tunnels-per-token`. |
| Public URL shows "Tunnel offline" (502) | The client is not connected right now (stopped, paused, or reconnecting). |
| Public URL shows "Local service unavailable" (502) | The tunnel is up but nothing answers on your target port - start your app. |
| `403 Blocked request ... host not allowed` from Vite/Django | Use the default `--host-header rewrite`, or allow the public host in your framework. |
| Browser cannot open `*.localhost` URLs | Chrome/Firefox resolve them; Safari may not. Use `curl -H "Host: <name>.localhost:8080" http://127.0.0.1:8080/`. |
| Dashboard says "Unlock" | Open the link from `tunnelr dashboard` (it carries the token), or paste the token after `#`. |
| `Target ... is a private-network address` | Add `--allow-private` if you really mean to expose a LAN/Docker service. |
| Large upload gets `413` | Raise the relay's `--max-body-mb`. |
| `429` from the relay | Per-tunnel rate limit (default 100 req/s); raise `--rate-limit` or slow the client. |

Add `--log-level debug` to `start` for connection-level diagnostics (secrets are masked in all log output).

## Development

```bash
npm test             # 119 tests: config, security, WebSocket, flow control, tunnelling, auth, limits, reconnects, dashboard API, CLI processes, TLS
npm run check        # dependency-free static checks: syntax, hygiene, secrets scan, docs cover every option
npm run typecheck    # TypeScript checkJs over the JSDoc annotations; needs: npm install --no-save typescript @types/node
npm run demo         # full local relay + client + app demonstration
```

The TLS tests generate a throw-away certificate with the `openssl` command-line tool and are skipped (visibly) if it is missing.

```
bin/tunnelr.js            CLI entry point
src/cli/                  argument parsing, help (generated from specs.js), terminal UI, commands
src/client/               tunnel client (reconnect, heartbeat, stats), local forwarding + SSRF guard, control API/dashboard server, state files
src/relay/                relay server (routing, auth, registry, limits), per-request streams, error pages
src/shared/               config, security primitives, WebSocket (RFC 6455), multiplexer + flow control, logging, HTTP helpers
dashboard/                static dashboard (HTML, CSS, JS - no build step)
test/                     automated tests (node:test)
docs/ deploy/             deployment guide, security model, feature status, Caddy/systemd examples
```

The wire protocol is documented at the top of [`src/shared/mux.js`](src/shared/mux.js).

## Limitations

HTTP/1.1 only (no HTTP/2 or HTTP/3 to visitors, no raw TCP tunnels); one relay process (no clustering; name reservations live in memory and are lost on restart);
all tunnels share the relay's TLS certificate and domain (no custom domains); the relay does not obtain certificates itself; no visitor-IP allow lists;
per-tunnel (not per-visitor) rate limiting; requests of one tunnel share one TCP connection, so a very congested uplink slows all of them; no keep-alive to your local app
(a fresh loopback connection per request, which avoids stale-socket errors). More in [docs/FEATURE_STATUS.md](docs/FEATURE_STATUS.md).

## License

No license has been selected, so none is granted: `package.json` says `UNLICENSED`/`private`. Choose a license (and add a `LICENSE` file) before
publishing or sharing this project; until then all rights remain with the author.
