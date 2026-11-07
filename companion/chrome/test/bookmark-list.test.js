import test from "node:test";
import assert from "node:assert/strict";
import { queryBookmarks } from "../bookmark-list.js";

test("chooser reads require the granted foreground top-level site", async () => {
  const sent = [];
  const api = {
    runtime: { id: "revisit", sendNativeMessage: async (_, request) => { sent.push(request); return { status: "bookmarks", items: [], cursor: null }; } },
    permissions: { contains: async () => true },
    windows: { getLastFocused: async () => ({ id: 1, focused: true }) },
    tabs: { query: async () => [{ id: 10, url: "https://x.com/home" }] },
  };
  const sender = { id: "revisit", frameId: 0, url: "https://x.com/home", tab: { id: 10, active: true, incognito: false } };
  const request = { kind: "listBookmarks", cursor: "" };
  for (const altered of [{ ...sender, id: "evil" }, { ...sender, frameId: 1 }, { ...sender, url: "https://facebook.com/" }, { ...sender, tab: { ...sender.tab, id: 99 } }]) {
    assert.equal((await queryBookmarks(api, request, altered)).status, "unavailable");
  }
  for (const cursor of [null, -1, "3:1", "0:01", "0:", "0:1<script>"]) await queryBookmarks(api, { ...request, cursor }, sender);
  assert.equal(sent.length, 0);
  await queryBookmarks(api, request, sender);
  await queryBookmarks(api, { kind: "openBookmark", cursor: "42" }, sender);
  assert.equal(sent.length, 2);
  assert.equal(sent[0].target, "x");
  assert.equal(sent[1].kind, "open");
  assert.equal(sent[1].cursor, "42");
  api.permissions.contains = async () => false;
  await queryBookmarks(api, request, sender);
  assert.equal(sent.length, 2);
});
