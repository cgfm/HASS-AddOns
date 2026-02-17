(function() {
  var match = window.location.href.match(/^(.*\/api\/hassio_ingress\/[^/]+)/);
  if (!match) return;
  var base = match[1];
  var prefix = new URL(base).pathname;
  var origin = window.location.origin;

  // ── URL rewriting helper ───────────────────────────────────────────
  function rewriteUrl(url) {
    if (url == null) return url;

    if (typeof url !== 'string') {
      if (url instanceof URL) url = url.toString();
      else if (url instanceof Request) return new Request(rewriteUrl(url.url), url);
      else return url;
    }

    // Already an ingress URL
    if (url.indexOf('/api/hassio_ingress/') !== -1) return url;

    // Absolute path: /foo → <prefix>/foo
    if (url.charAt(0) === '/' && url.charAt(1) !== '/') return prefix + url;

    // Full URL with same origin
    if (url.indexOf(origin) === 0) {
      var path = url.substring(origin.length);
      if (path.charAt(0) === '/') return origin + prefix + path;
    }

    return url;
  }

  // ── Patch Location.prototype.pathname (SPA router reads) ───────────
  var origPD = Object.getOwnPropertyDescriptor(Location.prototype, 'pathname');
  if (origPD && origPD.get) {
    Object.defineProperty(Location.prototype, 'pathname', {
      get: function() {
        var p = origPD.get.call(this);
        if (p.startsWith(prefix)) {
          var s = p.substring(prefix.length);
          return s.charAt(0) === '/' ? s : '/' + s;
        }
        return p;
      },
      set: function(v) {
        if (origPD.set) origPD.set.call(this, prefix + (v.charAt(0) === '/' ? v : '/' + v));
      },
      configurable: true
    });
  }

  // ── Patch Location.prototype.href (setter for navigations) ─────────
  var hrefPD = Object.getOwnPropertyDescriptor(Location.prototype, 'href');
  if (hrefPD) {
    Object.defineProperty(Location.prototype, 'href', {
      get: hrefPD.get,
      set: function(v) { hrefPD.set.call(this, rewriteUrl(v)); },
      configurable: true
    });
  }

  // ── Patch Location.assign / .replace ───────────────────────────────
  var origAssign = Location.prototype.assign;
  Location.prototype.assign = function(u) { return origAssign.call(this, rewriteUrl(u)); };
  var origLocReplace = Location.prototype.replace;
  Location.prototype.replace = function(u) { return origLocReplace.call(this, rewriteUrl(u)); };

  // ── Patch fetch ────────────────────────────────────────────────────
  var origFetch = window.fetch;
  window.fetch = function(input, opts) {
    if (typeof input === 'string') input = rewriteUrl(input);
    else if (input instanceof Request) input = rewriteUrl(input);
    else if (input instanceof URL) input = rewriteUrl(input.toString());
    return origFetch.call(this, input, opts);
  };

  // ── Patch XMLHttpRequest.open ──────────────────────────────────────
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    var args = Array.prototype.slice.call(arguments);
    args[1] = rewriteUrl(url);
    return origOpen.apply(this, args);
  };

  // ── Patch history.pushState / replaceState ─────────────────────────
  var origPush = history.pushState;
  history.pushState = function(s, t, u) { return origPush.call(this, s, t, rewriteUrl(u)); };
  var origReplaceState = history.replaceState;
  history.replaceState = function(s, t, u) { return origReplaceState.call(this, s, t, rewriteUrl(u)); };

  // ── Patch EventSource (PocketBase SSE realtime) ────────────────────
  if (typeof EventSource !== 'undefined') {
    var OrigES = EventSource;
    window.EventSource = function(u, o) { return new OrigES(rewriteUrl(u), o); };
    window.EventSource.prototype = OrigES.prototype;
    window.EventSource.CONNECTING = OrigES.CONNECTING;
    window.EventSource.OPEN = OrigES.OPEN;
    window.EventSource.CLOSED = OrigES.CLOSED;
  }

  // ── Patch window.open ──────────────────────────────────────────────
  var origWinOpen = window.open;
  window.open = function(u, t, f) { return origWinOpen.call(this, rewriteUrl(u), t, f); };
})();
