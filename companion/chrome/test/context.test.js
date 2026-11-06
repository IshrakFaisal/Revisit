import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { contextOf, observe, initialState, dueEvent, HOSTS } from "../context.js";

const view = (url, overrides = {}) => ({ focused: true, active: true, minimized: false, incognito: false, url, ...overrides });
let next = 0;
const id = () => `test-${++next}`;

test("only exact allowed HTTPS hosts qualify", () => {
  for (const host of ["x.com", "www.x.com"]) assert.equal(contextOf(view(`https://${host}/somewhere`)), "x");
  for (const host of ["github.com", "www.github.com"]) assert.equal(contextOf(view(`https://${host}/somewhere`)), "github");
  for (const url of [undefined, "bad", "http://x.com", "https://x.com.evil.test", "https://evilgithub.com", "https://github.com:8443", "https://user@x.com", "file:///x.com", "https://__proto__/", "https://api.github.com"]) assert.equal(contextOf(view(url)), null);
});
test("inactive, unfocused, minimized and incognito tabs cannot qualify", () => {
  for (const overrides of [{ active: false }, { focused: false }, { minimized: true }, { incognito: true }]) assert.equal(contextOf(view("https://github.com", overrides)), null);
});
test("Facebook and legitimate supported aliases map to the correct context", () => {
  for (const host of ["facebook.com", "www.facebook.com", "m.facebook.com", "mbasic.facebook.com"]) assert.equal(contextOf(view(`https://${host}/story.php?story_fbid=1`)), "facebook");
  for (const host of ["twitter.com", "www.twitter.com", "mobile.twitter.com"]) assert.equal(contextOf(view(`https://${host}/user/status/1`)), "x");
  assert.equal(contextOf(view("https://gist.github.com/user/1")), "github");
  for (const url of ["https://facebook.com.evil.test/", "https://facebook.com@evil.test/", "https://web.facebook.com/", "https://api.github.com/"]) assert.equal(contextOf(view(url)), null);
});
test("startup at a qualifying site establishes baseline without emitting", () => {
  const state = observe(initialState(), "x", 0, id);
  assert.equal(dueEvent(state, 10000, id), null);
});
test("new arrival waits two seconds; repeat events do not restart dwell", () => {
  let state = observe(initialState(), null, 0, id);
  state = observe(state, "github", 100, id);
  state = observe(state, "github", 1000, id);
  assert.equal(dueEvent(state, 2099, id), null);
  assert.equal(dueEvent(state, 2100, id).target, "github");
});
test("refresh and same-site navigation never create a second attempt", () => {
  let state = observe(observe(initialState(), null, 0, id), "x", 10, id);
  assert.ok(dueEvent(state, 2010, id));
  state.attempted = true;
  for (let i = 0; i < 100; i++) {
    state = observe(state, "x", 10000 + i, id);
    assert.equal(dueEvent(state, 10000 + i, id), null);
  }
});
test("leaving early cancels and return gets a new visit", () => {
  let state = observe(observe(initialState(), null, 0, id), "x", 0, id);
  const first = state.visitId;
  state = observe(state, null, 1000, id);
  assert.equal(dueEvent(state, 4000, id), null);
  state = observe(state, "x", 5000, id);
  assert.notEqual(state.visitId, first);
  assert.ok(dueEvent(state, 7000, id));
});
test("cross-site switch requires its own dwell", () => {
  let state = observe(initialState(), "x", 0, id);
  state = observe(state, "github", 100, id);
  assert.equal(dueEvent(state, 2100, id).target, "github");
});
test("restored session prevents replay after an uncertain send", () => {
  const state = observe(observe(initialState(), null, 0, id), "x", 0, id);
  state.attempted = true;
  const restored = JSON.parse(JSON.stringify(state));
  assert.equal(dueEvent(observe(restored, "x", 9000, id), 9000, id), null);
});
test("manifest has narrow opt-in permissions and stable native origin", () => {
  const manifest = JSON.parse(readFileSync(new URL("../manifest.json", import.meta.url)));
  assert.deepEqual(manifest.permissions, ["nativeMessaging", "storage", "activeTab", "contextMenus", "scripting"]);
  assert.equal(manifest.host_permissions, undefined);
  assert.equal(manifest.content_scripts, undefined);
  assert.equal(manifest.incognito, "not_allowed");
  assert.equal(manifest.optional_host_permissions.length, 12);
  assert.deepEqual(manifest.optional_host_permissions, HOSTS);
  const hash = createHash("sha256").update(Buffer.from(manifest.key, "base64")).digest("hex").slice(0, 32);
  assert.equal(hash.replace(/[0-9a-f]/g, x => String.fromCharCode(97 + parseInt(x, 16))), "eafjimobboehjlbhhpmcjchagfencibd");
});
