export const DWELL_MS = 2000;
export const HOST_CONTEXTS = Object.freeze({
  "x.com": "x", "www.x.com": "x",
  "twitter.com": "x", "www.twitter.com": "x", "mobile.twitter.com": "x",
  "facebook.com": "facebook", "www.facebook.com": "facebook",
  "m.facebook.com": "facebook", "mbasic.facebook.com": "facebook",
  "github.com": "github", "www.github.com": "github", "gist.github.com": "github",
});
export const HOSTS = Object.keys(HOST_CONTEXTS).map(host => `https://${host}/*`);

export function supportedSite(value) {
  if (typeof value !== "string" || /[\s\\\u0000-\u001f\u007f]/u.test(value) || /%(?![0-9a-f]{2})/i.test(value)) return null;
  try {
    const url = new URL(value);
    const source = Object.hasOwn(HOST_CONTEXTS, url.hostname) ? HOST_CONTEXTS[url.hostname] : null;
    if (!source || url.protocol !== "https:" || url.username || url.password || url.port) return null;
    return { source, url: url.href, origin: `${url.origin}/*` };
  } catch {
    return null;
  }
}

// Inspect only the active tab in the focused window, never a list of visited URLs.
export function contextOf(snapshot) {
  if (!snapshot?.focused || snapshot.minimized || !snapshot.active || snapshot.incognito) return null;
  return supportedSite(snapshot.url)?.source ?? null;
}

export function initialState() {
  return { initialized: false, target: null, since: 0, visitId: null, attempted: true };
}

// Pure state machine. Session state survives worker suspension, not browser restart.
export function observe(previous, target, now, newId) {
  if (!previous.initialized) {
    return { initialized: true, target, since: now, visitId: null, attempted: true };
  }
  if (previous.target === target) return previous;
  return {
    initialized: true, target, since: now,
    visitId: target ? newId() : null, attempted: !target,
  };
}

export function dueEvent(state, now, newId) {
  if (!state.target || state.attempted || now - state.since < DWELL_MS) return null;
  return { version: 1, target: state.target, eventId: newId(), visitId: state.visitId, occurredAt: now };
}
