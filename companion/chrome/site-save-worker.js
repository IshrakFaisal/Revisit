import { HOSTS, supportedSite } from "./context.js";
import { sendCapture } from "./capture.js";

const scriptId = "revisit-site-save";
const socialHosts = HOSTS.filter(pattern => supportedSite(pattern)?.source !== "github");

export async function syncSiteSaveScript(api) {
  const { origins = [] } = await api.permissions.getAll();
  const matches = socialHosts.filter(pattern => origins.includes(pattern));
  const [current] = await api.scripting.getRegisteredContentScripts({ ids: [scriptId] });
  if (!matches.length) {
    if (current) await api.scripting.unregisterContentScripts({ ids: [scriptId] });
    return;
  }
  const script = { id: scriptId, js: ["site-save.js"], matches, runAt: "document_idle" };
  if (current) await api.scripting.updateContentScripts([script]);
  else await api.scripting.registerContentScripts([script]);
}

export async function mayOfferSiteSave(api, sender) {
  const page = supportedSite(sender.url);
  return sender.id === api.runtime.id && sender.frameId === 0 &&
      sender.tab?.active === true && sender.tab?.incognito === false && !!page &&
      ["x", "facebook"].includes(page.source) && await api.permissions.contains({ origins: [page.origin] });
}

export async function handleSiteSave(api, request, sender) {
  const page = supportedSite(sender.url);
  const post = supportedSite(request.url);
  if (!post || page?.source !== post.source || !await mayOfferSiteSave(api, sender)) {
    return "Revisit could not confirm access to this post.";
  }
  return sendCapture(api, { url: post.url, incognito: false, siteSave: true });
}
