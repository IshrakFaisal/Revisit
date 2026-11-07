import { contextOf, dueEvent, DWELL_MS, HOSTS, initialState, observe, supportedSite } from "./context.js";
import { sendCapture } from "./capture.js";
import { handleSiteSave, mayOfferSiteSave, syncSiteSaveScript } from "./site-save-worker.js";

const HOST = "com.revisit.context";
const PAGE_WAIT_MS = 45000;
let chain = Promise.resolve();
let timer;

async function snapshot() {
  const window = await chrome.windows.getLastFocused();
  if (!window?.focused || window.state === "minimized") return null;
  const [tab] = await chrome.tabs.query({ active: true, windowId: window.id });
  const origin = supportedSite(tab?.url)?.origin;
  // activeTab belongs to the explicit Save action. Only an optional host grant
  // authorizes automatic observation, independently for each supported origin.
  const granted = origin && await chrome.permissions.contains({ origins: [origin] });
  return { focused: window.focused, minimized: window.state === "minimized",
    active: tab?.active, incognito: tab?.incognito, url: granted ? tab.url : undefined,
    tabId: tab?.id };
}

async function reconcile(reset = false, closedTabId) {
  clearTimeout(timer);
  const saved = await chrome.storage.session.get(["visit", "status"]);
  let previous = reset ? initialState() : (saved.visit ?? initialState());
  if (closedTabId !== undefined && closedTabId === previous.tabId) {
    previous = observe(previous, null, Date.now(), () => crypto.randomUUID());
  }
  const current = await snapshot();
  // Switching to the desktop editor pauses observation. It doesn't end a
  // visit already seen. An unfinished dwell still requires fresh focus time.
  if (!current && previous.initialized && previous.attempted) {
    await chrome.storage.session.set({ visit: previous });
    return;
  }
  const target = contextOf(current);
  const state = { ...observe(previous, target, Date.now(), () => crypto.randomUUID()),
    tabId: target ? current.tabId : null };
  let event = dueEvent(state, Date.now(), () => crypto.randomUUID());
  if (event) {
    if (event.target === "x" || event.target === "facebook") {
      // A document loading or an open Save prompt is not a delivery attempt.
      // Wait only while the real visit remains current; never retry native I/O.
      if (Date.now() - state.since >= PAGE_WAIT_MS) {
        state.attempted = true;
        await chrome.storage.session.set({ visit: state, status: "The page was not ready for a reminder. Leave the site and return to try again." });
        return;
      }
      if (!await browserPageReady(current, event.target)) {
        await chrome.storage.session.set({ visit: state, status: "Waiting for the page or its Save prompt to finish before checking reminders." });
        timer = setTimeout(() => enqueue(), 500);
        return;
      }
      event = dueEvent(state, Date.now(), () => crypto.randomUUID());
    }
    // Persist BEFORE sending: worker failure must not replay an uncertain delivery.
    state.attempted = true;
    await chrome.storage.session.set({ visit: state });
    try {
      if (event.target === "x" || event.target === "facebook") {
        await showBrowserReminder(event, current);
      } else {
        const result = await chrome.runtime.sendNativeMessage(HOST, event);
        const accepted = result?.status === "accepted";
        await chrome.storage.session.set({ status: accepted ? "Arrival queued for Revisit. This does not confirm evaluation or notification delivery." : `Receiver: ${result?.status ?? "invalid response"}` });
      }
    } catch {
      await chrome.storage.session.set({ status: "Receiver disconnected or host unavailable. No event queued. Leave and return after reconnecting." });
    }
  } else {
    await chrome.storage.session.set({ visit: state });
    if (state.target && !state.attempted) {
      timer = setTimeout(() => enqueue(), Math.max(1, DWELL_MS - (Date.now() - state.since)));
    }
  }
}

async function browserPageReady(current, target) {
  const { tabId, url } = current;
  if (!Number.isInteger(tabId)) return false;
  const message = data => chrome.tabs.sendMessage(tabId, data, { frameId: 0 });
  try {
    let ready;
    try {
      ready = await message({ kind: "revisitReminderReady" });
    } catch {
      // Open tabs may predate the extension reload or optional host grant.
      await chrome.scripting.executeScript({ target: { tabId }, files: ["site-save.js"] });
      ready = await message({ kind: "revisitReminderReady" });
    }
    const latest = await snapshot();
    return ready === true && latest?.tabId === tabId && latest.url === url && contextOf(latest) === target;
  } catch {
    return false;
  }
}

async function showBrowserReminder(event, current) {
  const { tabId, url } = current;
  const message = data => chrome.tabs.sendMessage(tabId, data, { frameId: 0 });
  const isSamePage = async () => {
    const latest = await snapshot();
    return latest?.tabId === tabId && latest.url === url && contextOf(latest) === event.target;
  };
  if (!await isSamePage()) return;
  const response = await chrome.runtime.sendNativeMessage(HOST, { ...event, version: 2 });
  let status;
  if (response?.status === "reminder") {
    const shown = await isSamePage() && await message({ kind: "revisitReminder", url: response.url, page: url });
    status = shown ? "Reminder shown on the site." : "The site changed before the reminder could be shown.";
  } else {
    status = response?.status === "no_reminder" ? "No saved item was eligible on this visit." : `Receiver: ${response?.status ?? "invalid response"}`;
  }
  await chrome.storage.session.set({ status });
}

function enqueue(reset = false, closedTabId) {
  chain = chain.then(() => reconcile(reset, closedTabId)).catch(async () => {
    // Losing observation continuity cannot establish a genuine arrival.
    clearTimeout(timer);
    await chrome.storage.session.set({ visit: initialState(), status: "Observation unavailable; waiting for a fresh baseline." });
  });
}

chrome.tabs.onActivated.addListener(() => enqueue());
chrome.tabs.onUpdated.addListener(() => enqueue());
chrome.tabs.onRemoved.addListener(tabId => enqueue(false, tabId));
chrome.windows.onFocusChanged.addListener(() => enqueue());
chrome.permissions.onAdded.addListener(() => enqueue(true));
chrome.permissions.onRemoved.addListener(() => enqueue(true));
chrome.runtime.onInstalled.addListener(() => enqueue(true));
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({ id: "revisit-save-page", title: "Save this page to Revisit", contexts: ["page"], documentUrlPatterns: HOSTS });
    chrome.contextMenus.create({ id: "revisit-save-link", title: "Save link to Revisit", contexts: ["link"], documentUrlPatterns: HOSTS, targetUrlPatterns: HOSTS });
  });
});
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!["revisit-save-page", "revisit-save-link"].includes(info.menuItemId)) return;
  const url = info.menuItemId === "revisit-save-link" ? info.linkUrl : (info.pageUrl ?? tab?.url);
  const captureStatus = await sendCapture(chrome, { url, incognito: tab?.incognito !== false });
  await chrome.storage.session.set({ captureStatus });
});
chrome.runtime.onStartup.addListener(() => enqueue(true));
let scriptSync = Promise.resolve();
function refreshSiteSaveScript() {
  scriptSync = scriptSync.then(() => syncSiteSaveScript(chrome)).catch(() =>
    chrome.storage.session.set({ captureStatus: "Site Save detection could not start. Use Save to Revisit from the extension popup." }));
}
chrome.runtime.onInstalled.addListener(refreshSiteSaveScript);
chrome.permissions.onAdded.addListener(refreshSiteSaveScript);
chrome.permissions.onRemoved.addListener(refreshSiteSaveScript);
chrome.runtime.onMessage.addListener((request, sender, respond) => {
  if (request?.kind === "canOfferSiteSave") {
    mayOfferSiteSave(chrome, sender).then(respond, () => respond(false));
    return true;
  }
  if (request?.kind !== "confirmSiteSave") return false;
  handleSiteSave(chrome, request, sender).then(respond, () => respond("Revisit could not open the draft."));
  return true;
});
// Resume a pending dwell after suspension; current browser state is always re-read.
enqueue();
