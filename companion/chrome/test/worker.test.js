import test from "node:test";
import assert from "node:assert/strict";
import { setImmediate as nextTurn } from "node:timers/promises";
import { HOSTS } from "../context.js";

// Chrome API double. This is a regression test, not a live Chrome visit.
test("worker rechecks focus, persists before sending and never retries failed visits", async t => {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"], now: 1700000000000 });
  const listeners = {};
  const signal = name => ({ addListener(fn) { (listeners[name] ??= []).push(fn); } });
  let activeUrl = "https://x.com/home";
  let activeId = 10;
  let focused = true;
  let fail = false;
  const data = {};
  const sent = [];
  const grants = new Set(HOSTS);
  const menus = [];
  const captures = [];
  const prompts = [];
  globalThis.chrome = {
    windows: { getLastFocused: async () => ({ id: 1, focused, state: "normal" }), onFocusChanged: signal("focus") },
    tabs: { query: async () => [{ id: activeId, active: true, url: activeUrl }],
      sendMessage: async (tabId, message) => {
        assert.equal(tabId, activeId);
        if (message.kind === "revisitReminder") prompts.push(message);
        return true;
      },
      onActivated: signal("active"), onUpdated: signal("update"), onRemoved: signal("remove") },
    permissions: { contains: async ({ origins }) => origins.every(origin => grants.has(origin)), onAdded: signal("grant"), onRemoved: signal("revoke") },
    contextMenus: {
      onClicked: signal("menu"),
      removeAll: callback => { menus.length = 0; callback(); },
      create: item => menus.push(item),
    },
    storage: { session: {
      get: async () => structuredClone(data),
      set: async values => Object.assign(data, structuredClone(values)),
    } },
    runtime: {
      onInstalled: signal("install"), onStartup: signal("startup"),
      onMessage: signal("message"),
      sendNativeMessage: async (host, event) => {
        assert.equal(host, "com.revisit.context");
        if (event.kind === "capture") {
          captures.push(event);
          if (fail) throw new Error("disconnected");
          return { status: "accepted" };
        }
        assert.equal(data.visit.attempted, true, "must persist before sending");
        sent.push(event);
        if (fail) throw new Error("disconnected");
        return event.version === 2 ? { status: "reminder", url: "https://x.com/saved/status/456" } : { status: "accepted" };
      },
    },
  };
  const settle = async () => { for (let i = 0; i < 5; i++) await nextTurn(); };
  const emit = async (name, ...args) => { for (const fn of listeners[name] ?? []) fn(...args); await settle(); };
  const advance = async ms => { t.mock.timers.tick(ms); await settle(); };
  try {
    await import(`../worker.js?test=${Date.now()}`);
    await settle();
    await advance(3000);
    assert.equal(sent.length, 0, "startup must only baseline");
    activeUrl = "https://example.com/";
    await emit("active");
    activeUrl = "https://github.com/";
    await emit("active");
    await advance(1999);
    assert.equal(sent.length, 0);
    await advance(1);
    assert.equal(sent.length, 1);
    assert.equal(sent[0].target, "github");
    assert.deepEqual(Object.keys(sent[0]).sort(), ["eventId", "occurredAt", "target", "version", "visitId"]);
    for (let i = 0; i < 100; i++) await emit("update");
    await advance(3000);
    assert.equal(sent.length, 1, "refresh burst must not reemit");
    focused = false;
    await emit("focus");
    activeUrl = "https://x.com/";
    await emit("update");
    await advance(3000);
    assert.equal(sent.length, 1, "background navigation must not qualify");
    focused = true;
    await emit("focus");
    await advance(1000);
    focused = false;
    await emit("focus");
    await advance(2000);
    assert.equal(sent.length, 1, "leaving during dwell cancels");
    fail = true;
    focused = true;
    await emit("focus");
    await advance(2000);
    assert.equal(sent.length, 2);
    assert.match(data.status, /disconnected/);
    fail = false;
    await emit("update");
    await advance(3000);
    assert.equal(sent.length, 2, "reconnect cannot replay an uncertain visit");
    await emit("grant");
    await advance(3000);
    assert.equal(sent.length, 2, "permission grant must baseline");
    grants.delete("https://www.facebook.com/*");
    activeUrl = "https://www.facebook.com/";
    await emit("active");
    await advance(3000);
    assert.equal(sent.length, 2, "activeTab must not authorize automatic monitoring without a host grant");
    grants.add("https://www.facebook.com/*");
    await emit("grant");
    await advance(3000);
    assert.equal(sent.length, 2, "granting Facebook permission only establishes its baseline");
    activeUrl = "https://example.org/";
    await emit("active");
    activeUrl = "https://www.facebook.com/user/posts/1";
    await emit("active");
    await advance(2000);
    assert.equal(sent.length, 3);
    assert.equal(sent[2].target, "facebook");
    assert.equal(sent[2].version, 2);
    assert.deepEqual(prompts[0], { kind: "revisitReminder", url: "https://x.com/saved/status/456", page: activeUrl });
    focused = false;
    await emit("focus");
    await advance(2500);
    focused = true;
    await emit("focus");
    await advance(2500);
    assert.equal(sent.length, 3, "returning from the Revisit editor to the same tab is still the same visit");
    await emit("remove", 99);
    await advance(2500);
    assert.equal(sent.length, 3, "closing a background tab must not cause a new arrival");
    // The replacement tab may already be active when the queued removal is handled.
    const oldId = activeId++;
    await emit("remove", oldId);
    await advance(1999);
    assert.equal(sent.length, 3);
    await advance(1);
    assert.equal(sent.length, 4, "closing and reopening the active site is a new visit");
    assert.equal(sent[3].target, "facebook");
    assert.notEqual(sent[3].visitId, sent[2].visitId);
    await emit("install");
    assert.equal(menus.length, 2);
    assert.deepEqual(menus[0].documentUrlPatterns, HOSTS);
    assert.deepEqual(menus[1].targetUrlPatterns, HOSTS);
    for (const click of listeners.menu) {
      await click({ menuItemId: "revisit-save-page", pageUrl: "https://www.facebook.com/user/posts/2" }, { incognito: false });
      await click({ menuItemId: "revisit-save-link", linkUrl: "https://x.com/user/status/3", pageUrl: "https://github.com/" }, { incognito: false });
      await click({ menuItemId: "revisit-save-link", linkUrl: "https://example.org/private" }, { incognito: false });
      await click({ menuItemId: "revisit-save-page", pageUrl: "https://github.com/org/repo" }, { incognito: true });
    }
    assert.equal(captures.length, 2);
    assert.equal(captures[0].source, "facebook");
    assert.equal(captures[1].url, "https://x.com/user/status/3", "capture must use selected permalink, not the containing page");
    assert.match(data.captureStatus, /Not saved/);
    assert.ok(!JSON.stringify(data).includes("https://"), "session data must not store URLs");
  } finally {
    delete globalThis.chrome;
    t.mock.timers.reset();
  }
});
