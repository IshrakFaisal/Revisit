import test from "node:test";
import assert from "node:assert/strict";

test("popup Save to Revisit sends the selected supported page only after a click", async () => {
  const elements = new Map();
  const element = selector => {
    if (!elements.has(selector)) elements.set(selector, {
      textContent: "", disabled: false,
      addEventListener(name, callback) { this[name] = callback; },
    });
    return elements.get(selector);
  };
  const data = {};
  let url = "https://x.com/user/status/1";
  let incognito = false;
  const sent = [];
  globalThis.document = { querySelector: element };
  globalThis.chrome = {
    tabs: { query: async query => {
      assert.deepEqual(query, { active: true, currentWindow: true });
      return [{ url, incognito }];
    } },
    permissions: {
      getAll: async () => ({ origins: ["https://x.com/*"] }),
      request: async () => true,
      remove: async () => true,
    },
    runtime: { sendNativeMessage: async (host, message) => {
      assert.equal(host, "com.revisit.context");
      sent.push(message);
      return { status: "accepted" };
    } },
    storage: { session: {
      get: async () => structuredClone(data),
      set: async value => Object.assign(data, structuredClone(value)),
    } },
  };
  try {
    await import(`../popup.js?test=${Date.now()}`);
    assert.equal(sent.length, 0, "opening the popup must not send a save request");
    assert.match(element("#permission").textContent, /1 of 12/);
    for (const [page, source] of [
      ["https://x.com/user/status/1", "x"],
      ["https://www.facebook.com/user/posts/2", "facebook"],
      ["https://github.com/org/repo", "github"],
    ]) {
      url = page;
      await element("#save").click();
      assert.equal(sent.at(-1).url, page);
      assert.equal(sent.at(-1).source, source);
      assert.equal(element("#save").disabled, false);
      assert.match(element("#capture-status").textContent, /Confirm/);
    }
    incognito = true;
    await element("#save").click();
    assert.equal(sent.length, 3);
    assert.match(element("#capture-status").textContent, /Not saved/);
    assert.equal(JSON.stringify(data).includes("https://"), false, "session state must not retain captured URLs");
  } finally {
    delete globalThis.document;
    delete globalThis.chrome;
  }
});
