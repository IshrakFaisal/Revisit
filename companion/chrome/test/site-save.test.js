import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { handleSiteSave, syncSiteSaveScript } from "../site-save-worker.js";

const code = readFileSync(new URL("../site-save.js", import.meta.url), "utf8");
const tick = () => new Promise(resolve => setImmediate(resolve));

// Small DOM fixture for the actual isolated content script. No site requests.
function fixture(source, captureReply = "Draft sent to Revisit.") {
  const isX = source === "x";
  const url = isX ? "https://x.com/person/status/123" : "https://www.facebook.com/person/posts/123";
  let click, observer, onMessage, saved = false;
  const opened = [];
  class Element {
    children = [];
    events = {};
    textContent = "";
    isConnected = true;
    setAttribute() {}
    getAttribute() { return null; }
    addEventListener(name, callback) { this.events[name] = callback; }
    append(...children) { this.children.push(...children); }
    attachShadow() { return this.shadow = new Element(); }
    remove() { this.isConnected = false; }
    querySelectorAll() { return []; }
    closest() { return null; }
    getClientRects() { return [1]; }
  }
  const article = new Element();
  const anchor = Object.assign(new Element(), { href: url, closest: () => article, querySelector: () => ({}) });
  const control = Object.assign(new Element(), { closest: () => article });
  article.querySelectorAll = selector => selector === "a[href]" ? [anchor] : saved ? [control] : [];
  const target = Object.assign(new Element(), { closest: selector => selector.includes('data-testid="bookmark"') || selector.includes('Actions for this post') ? control : null });
  const menuItem = Object.assign(new Element(), { closest: () => ({}) });
  const saveMenu = Object.assign(new Element(), { textContent: "Save post", closest: selector => selector.includes('role="menuitem"') ? menuItem : null });
  const notice = Object.assign(new Element(), { textContent: "Post saved" });
  const body = new Element();
  const messages = [];
  runInNewContext(code, {
    Element, URL, location: Object.assign(new URL(url), { assign: value => opened.push(value) }), queueMicrotask,
    setTimeout: () => 1, clearTimeout: () => {},
    document: { body, visibilityState: "visible", createElement: () => new Element(),
      addEventListener: (_, callback) => { click = callback; }, querySelectorAll: () => saved ? [notice] : [] },
    MutationObserver: class { constructor(callback) { observer = callback; } observe() {} disconnect() {} },
    chrome: { runtime: { id: "revisit", onMessage: { addListener: callback => { onMessage = callback; } }, sendMessage: async message => { messages.push(message); return message.kind === "canOfferSiteSave" ? true : captureReply; } } },
  });
  return {
    url, messages, opened,
    reminder: value => onMessage({ kind: "revisitReminder", page: url, url: value }, { id: "revisit" }, () => {}),
    start: (trusted = true) => { click({ target, isTrusted: trusted }); if (!isX) click({ target: saveMenu, isTrusted: trusted }); },
    confirm: () => { saved = true; observer?.(); },
    panel: () => body.children.find(node => node.isConnected)?.shadow?.children[1],
  };
}

test("the in-page reminder opens the exact saved post only on Yes", async () => {
  const page = fixture("x");
  page.reminder("javascript:alert(1)");
  assert.equal(page.panel(), undefined);
  const savedUrl = "https://x.com/saved/status/456";
  page.reminder(savedUrl);
  assert.match(page.panel().children[0].textContent, /See it now/);
  page.panel().children[2].events.click({ isTrusted: true });
  assert.deepEqual(page.opened, []);
  page.reminder(savedUrl);
  await page.panel().children[1].events.click({ isTrusted: true });
  assert.deepEqual(page.opened, [savedUrl]);
});

for (const source of ["x", "facebook"]) {
  test(`${source} waits for native save confirmation and sends a post only on Yes`, async () => {
    const declined = fixture(source);
    declined.start();
    await tick();
    assert.equal(declined.panel(), undefined);
    declined.confirm();
    await tick();
    assert.equal(declined.panel().children[0].textContent, "Add this post to Revisit?");
    declined.panel().children[2].events.click({ isTrusted: true });
    assert.equal(declined.panel(), undefined);
    assert.deepEqual(declined.messages.map(message => message.kind), ["canOfferSiteSave"]);

    const accepted = fixture(source);
    accepted.start(false);
    accepted.confirm();
    await tick();
    assert.equal(accepted.panel(), undefined, "synthetic page click must not qualify");
    const genuine = fixture(source);
    genuine.start();
    genuine.confirm();
    await tick();
    await genuine.panel().children[1].events.click({ isTrusted: true });
    assert.equal(genuine.messages[1].kind, "confirmSiteSave");
    assert.equal(genuine.messages[1].url, genuine.url);
    assert.equal(genuine.panel(), undefined, "successful capture hands off to the app without a second message");
  });
}

test("capture failure keeps the prompt with its error and allows retry", async () => {
  const page = fixture("x", "Not saved. Open Revisit and try again.");
  page.start(); page.confirm(); await tick();
  await page.panel().children[1].events.click({ isTrusted: true });
  assert.match(page.panel().children[0].textContent, /Not saved/);
  assert.equal(page.panel().children[1].disabled, false);
});

test("social observer registers only granted X and Facebook origins", async () => {
  let scripts;
  await syncSiteSaveScript({
    permissions: { getAll: async () => ({ origins: ["https://x.com/*", "https://github.com/*", "https://www.facebook.com/*"] }) },
    scripting: { getRegisteredContentScripts: async () => [], registerContentScripts: async value => { scripts = value; } },
  });
  assert.deepEqual(scripts[0].matches, ["https://x.com/*", "https://www.facebook.com/*"]);
});

test("confirmed social capture rejects revoked, cross-site and nested-frame requests", async () => {
  const messages = [];
  const api = { runtime: { id: "revisit", sendNativeMessage: async (_, message) => { messages.push(message); return { status: "accepted" }; } },
    permissions: { contains: async () => true } };
  const sender = { id: "revisit", frameId: 0, url: "https://x.com/home", tab: { active: true, incognito: false } };
  const request = { url: "https://x.com/person/status/123" };
  await handleSiteSave(api, request, { ...sender, frameId: 1 });
  await handleSiteSave(api, { url: "https://www.facebook.com/person/posts/123" }, sender);
  assert.equal(messages.length, 0);
  await handleSiteSave(api, request, sender);
  assert.equal(messages[0].kind, "siteSave");
  api.permissions.contains = async () => false;
  await handleSiteSave(api, request, sender);
  assert.equal(messages.length, 1);
});
