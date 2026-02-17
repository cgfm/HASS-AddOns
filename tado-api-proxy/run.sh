#!/bin/sh
set -e

# ── Logging ────────────────────────────────────────────────────────────
log_info()  { printf '[INFO]  %s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
log_warn()  { printf '[WARN]  %s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
log_error() { printf '[ERROR] %s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
log_fatal() { printf '[FATAL] %s  %s\n' "$(date '+%H:%M:%S')" "$*"; exit 1; }

log_info "Starting Tado API Proxy add-on..."

# ── Read options ───────────────────────────────────────────────────────
OPTIONS_FILE="/data/options.json"
[ -f "$OPTIONS_FILE" ] || log_fatal "Options file not found: $OPTIONS_FILE"

log_info "Reading configuration..."

# Dump options keys for debugging (never log actual password)
log_info "Options file keys: $(jq -r 'keys | join(", ")' "$OPTIONS_FILE")"
log_info "Options non-empty fields: $(jq -r 'to_entries | map(select(.value != "" and .value != null)) | map(.key) | join(", ")' "$OPTIONS_FILE")"

SUPERUSER_EMAIL=$(jq -r '.superuser_email // empty' "$OPTIONS_FILE")
SUPERUSER_PASSWORD=$(jq -r '.superuser_password // empty' "$OPTIONS_FILE")

if [ -z "$SUPERUSER_EMAIL" ]; then
    log_error "superuser_email is empty or missing in options.json"
    log_error "Raw value: $(jq '.superuser_email' "$OPTIONS_FILE")"
    log_fatal "Please set a valid email in the add-on configuration and restart."
fi

if [ -z "$SUPERUSER_PASSWORD" ]; then
    log_error "superuser_password is empty or missing in options.json"
    log_fatal "Please set a password in the add-on configuration and restart."
fi

PW_LEN=$(printf '%s' "$SUPERUSER_PASSWORD" | wc -c)
log_info "Superuser email: ${SUPERUSER_EMAIL}"
log_info "Superuser password length: ${PW_LEN} characters"

if [ "$PW_LEN" -lt 8 ]; then
    log_fatal "Password must be at least 8 characters (PocketBase requirement). Current: ${PW_LEN}"
fi

export SUPERUSER_EMAIL SUPERUSER_PASSWORD

# ── Detect ingress path ───────────────────────────────────────────────
INGRESS_PATH=""
if [ -n "$SUPERVISOR_TOKEN" ]; then
    log_info "Querying Supervisor for ingress path..."
    if RESP=$(curl -sSf \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        http://supervisor/addons/self/info 2>&1); then
        # Extract, strip whitespace/CR, and remove all trailing slashes
        INGRESS_PATH=$(printf '%s' "$RESP" | jq -r '.data.ingress_url // empty' | tr -d '\r\n ')
        # shellcheck disable=SC2295
        while [ "${INGRESS_PATH%/}" != "$INGRESS_PATH" ]; do
            INGRESS_PATH="${INGRESS_PATH%/}"
        done
        log_info "Ingress path: '${INGRESS_PATH}'"
        log_info "Ingress path length: $(printf '%s' "$INGRESS_PATH" | wc -c) chars, last char: '$(printf '%s' "$INGRESS_PATH" | tail -c 1)'"
    else
        log_warn "Supervisor API query failed: ${RESP}"
        log_warn "Ingress URL rewriting will be disabled"
    fi
else
    log_info "No SUPERVISOR_TOKEN — running outside Home Assistant"
fi

# ── Render nginx config ───────────────────────────────────────────────
log_info "Generating nginx configuration..."
sed "s|%%INGRESS_PATH%%|${INGRESS_PATH}|g" \
    /etc/nginx/templates/default.conf.template \
    > /etc/nginx/http.d/default.conf

# ── Generate auto-auth.js ─────────────────────────────────────────────
# Credentials are base64-encoded to avoid any shell/sed escaping issues
# with special characters in email or password.
log_info "Generating auto-auth script..."

AUTH_EMAIL_JS=$(printf '%s' "$SUPERUSER_EMAIL" | jq -Rs .)
AUTH_PASS_JS=$(printf '%s' "$SUPERUSER_PASSWORD" | jq -Rs .)
CREDS_B64=$(printf '{"identity":%s,"password":%s}' "$AUTH_EMAIL_JS" "$AUTH_PASS_JS" \
    | base64 | tr -d '\n')

cat > /usr/share/auto-auth.js << AUTOAUTH
(function() {
  var TAG = '[auto-auth]';

  // Only run when accessed through HA Ingress
  if (window.location.href.indexOf('/api/hassio_ingress/') === -1) {
    console.debug(TAG, 'Direct access detected, skipping auto-auth');
    return;
  }

  // Check for a valid existing token
  try {
    var stored = JSON.parse(localStorage.getItem('pocketbase_auth'));
    if (stored && stored.token) {
      var payload = JSON.parse(atob(stored.token.split('.')[1]));
      if (payload.exp && payload.exp * 1000 > Date.now() + 60000) {
        console.debug(TAG, 'Valid token exists, expires', new Date(payload.exp * 1000).toISOString());
        return;
      }
      console.log(TAG, 'Token expired or expiring soon, re-authenticating');
    }
  } catch(e) {
    console.debug(TAG, 'No valid stored token');
  }

  // Clear stale auth state
  localStorage.removeItem('pocketbase_auth');

  // Authenticate with superuser credentials (base64-encoded to avoid injection)
  var body = atob('${CREDS_B64}');

  try {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '/api/collections/_superusers/auth-with-password', false);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(body);

    if (xhr.status === 200) {
      var data = JSON.parse(xhr.responseText);
      localStorage.setItem('pocketbase_auth', JSON.stringify({
        token: data.token,
        record: data.record || data.admin || data.model || {}
      }));
      console.log(TAG, 'Authenticated successfully');
    } else {
      console.error(TAG, 'Auth failed: HTTP', xhr.status, xhr.responseText.substring(0, 200));
    }
  } catch(e) {
    console.error(TAG, 'Request failed:', e.message || e);
  }
})();
AUTOAUTH

log_info "Auto-auth script written to /usr/share/auto-auth.js"

# ── Superuser management ──────────────────────────────────────────────
if [ -f "/data/pb_data/data.db" ]; then
    log_info "Existing database found — upserting superuser credentials..."
    if OUTPUT=$(/usr/local/bin/tado-api-proxy superuser upsert \
        "$SUPERUSER_EMAIL" "$SUPERUSER_PASSWORD" \
        --dir /data/pb_data 2>&1); then
        log_info "Superuser upserted successfully"
    else
        log_error "Superuser upsert failed: ${OUTPUT}"
        log_info "Attempting superuser create as fallback..."
        if OUTPUT=$(/usr/local/bin/tado-api-proxy superuser create \
            "$SUPERUSER_EMAIL" "$SUPERUSER_PASSWORD" \
            --dir /data/pb_data 2>&1); then
            log_info "Superuser created successfully"
        else
            log_error "Superuser create failed: ${OUTPUT}"
            log_warn "Will rely on SUPERUSER_EMAIL/SUPERUSER_PASSWORD env vars at serve startup"
        fi
    fi
else
    log_info "No existing database — PocketBase will initialize on first start"
    log_info "Superuser will be created automatically from SUPERUSER_EMAIL/SUPERUSER_PASSWORD env vars"
fi

# ── Start nginx ────────────────────────────────────────────────────────
log_info "Starting nginx (port 8080)..."
nginx
log_info "nginx started"

# ── Start PocketBase ──────────────────────────────────────────────────
log_info "Starting tado-api-proxy (PocketBase) on 127.0.0.1:8099..."
log_info "Web UI is available via the Home Assistant sidebar"

exec /usr/local/bin/tado-api-proxy serve \
    --dir /data/pb_data \
    --http 127.0.0.1:8099
