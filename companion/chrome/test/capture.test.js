import test from "node:test";
import assert from "node:assert/strict";
import { captureMessage, sendCapture } from "../capture.js";

const eventId = "12345678-1234-1234-1234-123456789abc";
const now = 1700000000000;

test("explicit capture supports X, Facebook and GitHub items independently of reminder trigger", () => {
  for (const [url, source] of [
    ["https://x.com/user/status/123", "x"],
    ["https://www.facebook.com/user/posts/123", "facebook"],
    ["https://github.com/org/repo/issues/42", "github"],
  ]) {
    const message = captureMessage(url, false, now, () => eventId);
    assert.deepEqual(message, { version: 1, kind: "capture", url, source, eventId, occurredAt: now });
    assert.equal(message.trigger, undefined, "the user must select a separate trigger in Revisit");
  }
});

test("capture rejects incognito, invalid, credentialed and unsupported links", () => {
  assert.equal(captureMessage("https://x.com/u/status/1", true, now, () => eventId), null);
  for (const url of [
    undefined, "bad", "http://x.com/post", "https://x.com.evil.test/post",
    "https://user:password@facebook.com/post", "https://facebook.com:8443/post",
    "https://example.org/article", "https://x.com/a\\b", "https://x.com/%zz",
    "https://x.com/a\n", `https://github.com/${"x".repeat(3072)}`,
  ]) assert.equal(captureMessage(url, false, now, () => eventId), null, String(url));
});

test("capture normalizes browser URLs to a bounded ASCII transport", () => {
  assert.equal(captureMessage("https://x.com/u/😀", false, now, () => eventId).url, "https://x.com/u/%F0%9F%98%80");
  for (const [url, source] of [
    ["https://mobile.twitter.com/u/status/1", "x"],
    ["https://m.facebook.com/story.php?id=1", "facebook"],
    ["https://mbasic.facebook.com/story.php?id=1", "facebook"],
    ["https://gist.github.com/u/123", "github"],
  ]) assert.equal(captureMessage(url, false, now, () => eventId).source, source);
  const prefix = "https://x.com/";
  const boundary = prefix + "x".repeat(3072 - prefix.length);
  assert.equal(captureMessage(boundary, false, now, () => eventId).url.length, 3072);
  assert.equal(captureMessage(boundary + "x", false, now, () => eventId), null);
});

test("capture percent-encodes raw browser resource characters accepted by WHATWG URLs", () => {
  for (const value of ["a|b", "a^b", "{topic}", "<topic>", 'a"b', "a`b", "বাংলা😀"]) {
    const query = captureMessage(`https://github.com/org/repo?q=${value}`, false, now, () => eventId);
    assert.equal(new URL(query.url).searchParams.get("q"), value);
    assert.doesNotMatch(query.url, /[<>"{}|^`]/u, "native and Dart validators require escaped resource characters");
    const fragment = captureMessage(`https://www.facebook.com/post#${value}`, false, now, () => eventId);
    assert.equal(decodeURIComponent(new URL(fragment.url).hash.slice(1)), value);
    assert.doesNotMatch(fragment.url, /[<>"{}|^`]/u);
  }
  assert.equal(captureMessage(`https://github.com/${"^".repeat(1100)}`, false, now, () => eventId), null, "limit applies after percent encoding expands the URL");
});

test("accepted native capture means a queued draft, not a persisted save", async () => {
  let received;
  const api = { runtime: { sendNativeMessage: async (host, message) => {
    assert.equal(host, "com.revisit.context");
    received = message;
    return { status: "accepted" };
  } } };
  const status = await sendCapture(api, { url: "https://github.com/org/repo", incognito: false });
  assert.equal(received.kind, "capture");
  assert.match(status, /draft/i);
  assert.match(status, /confirm.*save/i);
});

test("capture handles missing hosts, busy receivers and invalid responses truthfully", async () => {
  for (const outcome of ["throw", "busy", undefined]) {
    const api = { runtime: { sendNativeMessage: async () => {
      if (outcome === "throw") throw new Error("host unavailable");
      return outcome ? { status: outcome } : {};
    } } };
    const result = await sendCapture(api, { url: "https://x.com/u/status/1", incognito: false });
    assert.doesNotMatch(result, /draft sent/i);
    assert.match(result, /not saved/i);
  }
});
