import { supportedSite } from "./context.js";

export function captureMessage(url, incognito, now, newId, siteSave = false) {
  if (incognito) return null;
  const site = supportedSite(url);
  if (!site || (siteSave && !["x", "facebook"].includes(site.source))) return null;
  // WHATWG URLs can retain these raw query/fragment characters. Encode them
  // for the existing native and Dart URL boundaries while preserving values.
  const transportUrl = site.url.replace(/[<>"{}|^`]/gu, character => encodeURIComponent(character));
  if (transportUrl.length > 3072 || /[^\x20-\x7e]/u.test(transportUrl)) return null;
  return {
    version: 1, kind: siteSave ? "siteSave" : "capture", url: transportUrl, source: site.source,
    eventId: newId(), occurredAt: now,
  };
}

export async function sendCapture(api, { url, incognito, siteSave = false }) {
  const message = captureMessage(url, incognito, Date.now(), () => crypto.randomUUID(), siteSave);
  if (!message) return "Not saved. Choose an HTTPS X, Facebook or GitHub link of at most 3,072 encoded characters outside incognito.";
  try {
    const reply = await api.runtime.sendNativeMessage("com.revisit.context", message);
    if (reply?.status === "accepted") return "Draft sent to Revisit. Confirm the item, enter its title and intention, choose priority and reminder context, then save in the app.";
    return `Not saved. Revisit receiver: ${reply?.status ?? "invalid response"}. Keep the app running and try Save to Revisit again.`;
  } catch {
    return "Not saved. Revisit is disconnected or its native host is unavailable. Open Revisit, check setup, then try Save to Revisit again.";
  }
}
