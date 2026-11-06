import { HOSTS } from "./context.js";
import { sendCapture } from "./capture.js";

async function refresh() {
  const granted = await chrome.permissions.getAll();
  const enabledCount = HOSTS.filter(origin => granted.origins?.includes(origin)).length;
  document.querySelector("#permission").textContent = enabledCount === HOSTS.length ? "Site access enabled. Leave this site, then return for two seconds." : `Site access enabled for ${enabledCount} of ${HOSTS.length} supported origins. Automatic detection works only on granted origins.`;
  const { status, captureStatus } = await chrome.storage.session.get(["status", "captureStatus"]);
  document.querySelector("#status").textContent = status ?? "No delivery attempted this browser session.";
  document.querySelector("#capture-status").textContent = captureStatus ?? "Save the current page, or use its permalink's right-click menu.";
}

document.querySelector("#save").addEventListener("click", async () => {
  const button = document.querySelector("#save");
  button.disabled = true;
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const captureStatus = await sendCapture(chrome, { url: tab?.url, incognito: tab?.incognito !== false });
    await chrome.storage.session.set({ captureStatus });
    await refresh();
  } finally {
    button.disabled = false;
  }
});
document.querySelector("#enable").addEventListener("click", async () => {
  await chrome.permissions.request({ origins: HOSTS });
  await refresh();
});
document.querySelector("#disable").addEventListener("click", async () => {
  await chrome.permissions.remove({ origins: HOSTS });
  await refresh();
});
await refresh();
