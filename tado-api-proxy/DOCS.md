# Tado API Proxy – Documentation

## What is tado-api-proxy?

[tado-api-proxy](https://github.com/s1adem4n/tado-api-proxy) is a reverse proxy
that bypasses tado's API rate limits (100–20,000 calls/day depending on your
subscription). It supports:

- **Multiple tado accounts** with automatic load balancing
- **Official tado API authorization** for a separate, higher rate limit
- **Web UI** for account management, token monitoring, and request statistics
- **OAuth2 Device Code Flow** – no headless browser or password storage required
- **Protected access** with optional proxy tokens

## First-time setup

1. **Configure admin credentials** – In the add-on configuration, set
   `superuser_email` and `superuser_password`. These are the **proxy admin
   credentials** for the Web UI, NOT your tado account credentials.
2. **Start the add-on**.
3. **Open the Web UI** – Click "Tado API Proxy" in the Home Assistant sidebar.
4. **Log in** with the admin credentials you configured.
5. **Add a tado account** – Click "Add Account" in the Web UI. The proxy will
   initiate the OAuth2 Device Code Flow and display a URL and a code.
6. **Authorize in your browser** – Open the displayed URL on any device, enter
   the code, and log in to your tado account.
7. **Done** – The proxy now has a valid token and will refresh it automatically.
8. **Optional: Authorize the official API** – In the Web UI, click "Authorize
   Official API" for reduced ban risk (routes requests through tado's official
   client with a separate, higher rate limit).

## Ingress vs LAN access

By default, the proxy is **only accessible through the Home Assistant sidebar**
(Ingress). No ports are exposed to your network.

To make the proxy accessible on your local network:

1. Enable `Expose to LAN` in the add-on configuration.
2. Set the port mapping to `8080` in the add-on network configuration.
3. Access the proxy at `http://<your-HA-IP>:8080`.

The API endpoint is available at `http://<your-HA-IP>:8080/api/v2/...`.

## Integration with Home Assistant tado

The official tado integration does **not** support custom API URLs. Use one of
these alternatives:

### Option A: tado_hijack (Recommended)

[tado_hijack](https://github.com/banter240/tado_hijack) is a HACS custom
integration that natively supports the proxy via a configuration option. Install
it through HACS and point it to the proxy URL.

### Option B: tado_ce

[tado_ce](https://github.com/hiall-fyi/tado_ce) is another HACS custom
integration that supports proxy configuration.

### Option C: Manual PyTado modification

Edit `PyTado/http.py` to change the API base URL. This requires SSH access and
changes are lost on Home Assistant updates.

## Protected access

Enable "Protected Access" in the Web UI settings to require a proxy token for
API access. When enabled, use `/<proxy_token>/api/v2/...` instead of
`/api/v2/...`.

## Reducing ban risks

To minimize the risk of being rate-limited or banned by tado:

- **Authorize the official API** – This is the most effective step; it routes
  requests through tado's official client which has a separate, higher rate limit.
- **Add multiple secondary accounts** – The proxy load-balances requests across
  all configured accounts.
- **Randomize request intervals** – Avoid sending requests at fixed intervals.
- **Reduce overnight activity** – Lower the polling frequency during nighttime.

## Troubleshooting

- **Check add-on logs** – The add-on logs show startup information, errors, and
  request statistics.
- **Verify tado account tokens** – Open the Web UI and check that your tado
  accounts show valid tokens.
- **PocketBase admin dashboard** – Available at `/_/` (superuser login required).
- **Token refresh errors** – If a token fails to refresh, remove the account in
  the Web UI and re-add it using the Device Code Flow.
- **Ingress issues** – If the Web UI doesn't load correctly through the sidebar,
  try accessing it via LAN (enable `Expose to LAN` and map port 8080).
