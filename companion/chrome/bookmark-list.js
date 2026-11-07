import { supportedSite } from "./context.js";
import { mayOfferSiteSave } from "./site-save-worker.js";

export async function queryBookmarks(api, request, sender) {
  const kind = request.kind === "listBookmarks" ? "list" : request.kind === "openBookmark" ? "open" : null;
  const cursor = request.cursor;
  if (!kind || typeof cursor !== "string" || !(kind === "list" ? /^(?:[0-2]:[1-9][0-9]{0,14})?$/ : /^[1-9][0-9]{0,14}$/).test(cursor) ||
      !await mayOfferSiteSave(api, sender)) return { status: "unavailable" };
  const window = await api.windows.getLastFocused();
  if (!window?.focused || window.state === "minimized") return { status: "unavailable" };
  const [tab] = await api.tabs.query({ active: true, windowId: window.id });
  if (tab?.id !== sender.tab.id || supportedSite(tab.url)?.source !== supportedSite(sender.url)?.source) return { status: "unavailable" };
  try {
    return await api.runtime.sendNativeMessage("com.revisit.context", {
      version: 1, kind, target: supportedSite(sender.url).source, cursor,
      eventId: crypto.randomUUID(), occurredAt: Date.now(),
    });
  } catch { return { status: "disconnected" }; }
}
