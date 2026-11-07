import test from "node:test";
import assert from "node:assert/strict";
import { setImmediate as nextTurn } from "node:timers/promises";

// Real worker, controlled browser APIs. This is not live-site evidence.
async function browser(t, name) {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"], now: 1700000000000 });
  const state = { url: "https://example.org/", ready: false, missing: false, focused: true, granted: true };
  const data = {}, listeners = {}, sent = [], shown = [];
  const signal = name => ({ addListener(fn) { (listeners[name] ??= []).push(fn); } });
  globalThis.chrome = {
    windows: { getLastFocused: async () => ({ id: 1, focused: state.focused }), onFocusChanged: signal("focus") },
    tabs: { query: async () => [{ id: 1, active: true, incognito: false, url: state.url }],
      onActivated: signal("active"), onUpdated: signal("update"), onRemoved: signal("remove"),
      sendMessage: async (_, message) => {
        if (state.missing) throw Error("Document is loading");
        if (message.kind === "revisitReminder") shown.push(message);
        return state.ready;
      } },
    scripting: { executeScript: async () => { if (state.missing) throw Error("No document yet"); } },
    permissions: { contains: async () => state.granted, onAdded: signal("grant"), onRemoved: signal("revoke") },
    contextMenus: { onClicked: signal("menu") },
    runtime: { onInstalled: signal("install"), onStartup: signal("startup"), onMessage: signal("message"),
      sendNativeMessage: async (_, event) => {
        assert.equal(data.visit.attempted, true, "persist before native handoff");
        sent.push(event);
        return { status: "reminder", url: "https://x.com/saved/status/123" };
      } },
    storage: { session: { get: async () => structuredClone(data), set: async value => Object.assign(data, structuredClone(value)) } },
  };
  t.after(() => { delete globalThis.chrome; t.mock.timers.reset(); });
  const settle = async () => { for (let i = 0; i < 8; i++) await nextTurn(); };
  const emit = async name => { for (const fn of listeners[name] ?? []) fn(); await settle(); };
  const advance = async ms => { t.mock.timers.tick(ms); await settle(); };
  await import(`../worker.js?readiness=${name}`);
  await settle();
  state.url = "https://x.com/home";
  await emit("active");
  await advance(2000);
  return { state, data, sent, shown, emit, advance };
}

test("a busy save prompt does not consume the later reminder visit", async t => {
  const b = await browser(t, "busy");
  assert.equal(b.sent.length, 0);
  assert.equal(b.data.visit.attempted, false);
  await b.advance(10000);
  b.state.ready = true;
  await b.advance(500);
  assert.equal(b.sent.length, 1);
  assert.equal(b.shown.length, 1);
  assert.equal(b.sent[0].occurredAt, Date.now(), "create fresh arrival at actual handoff");
  await b.emit("update");
  await b.advance(10000);
  assert.equal(b.sent.length, 1);
  assert.ok(!JSON.stringify(b.data).includes("https://"));
});

test("loading-document injection failure can recover before any native handoff", async t => {
  const b = await browser(t, "loading");
  b.state.missing = true;
  await b.advance(500);
  assert.equal(b.data.visit.attempted, false);
  b.state.missing = false;
  b.state.ready = true;
  await b.advance(500);
  assert.equal(b.sent.length, 1);
});

test("pending page readiness is bounded and cannot replay after expiry", async t => {
  const b = await browser(t, "expiry");
  await b.advance(45000);
  b.state.ready = true;
  await b.emit("update");
  await b.advance(1000);
  assert.equal(b.sent.length, 0);
  assert.equal(b.data.visit.attempted, true);
  assert.match(b.data.status, /not ready/);
});

test("leaving or revoking permission cancels pending page readiness", async t => {
  const b = await browser(t, "leave");
  b.state.url = "https://example.org/";
  await b.emit("active");
  b.state.ready = true;
  await b.advance(1000);
  assert.equal(b.sent.length, 0);
  b.state.url = "https://x.com/";
  b.state.ready = false;
  await b.emit("active");
  await b.advance(2000);
  b.state.granted = false;
  await b.emit("revoke");
  b.state.ready = true;
  await b.advance(1000);
  assert.equal(b.sent.length, 0);
});
