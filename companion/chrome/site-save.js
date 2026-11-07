// Runs in the extension's isolated world on granted X and Facebook pages.
// Only inspect controls and permalinks connected to the user's current action.
(() => {
  if (globalThis.revisitSocialPageLoaded) return;
  const xHosts = new Set(["x.com", "www.x.com", "twitter.com", "www.twitter.com", "mobile.twitter.com"]);
  const facebookHosts = new Set(["facebook.com", "www.facebook.com", "m.facebook.com", "mbasic.facebook.com"]);
  const onX = xHosts.has(location.hostname);
  if (!onX && !facebookHosts.has(location.hostname)) return;
  globalThis.revisitSocialPageLoaded = true;
  const articleSelector = onX ? 'article[data-testid="tweet"]' : '[role="article"],article';
  const liveSelector = '[role="alert"],[role="status"],[aria-live="polite"],[aria-live="assertive"]';
  let pendingMenu;
  let watching = false;
  let prompt;

  function permalink(href) {
    try {
      const url = new URL(href, location.href);
      if (url.protocol !== "https:" || url.port || url.username || url.password) return null;
      if (onX) {
        if (!xHosts.has(url.hostname) || !/^\/(?:[A-Za-z0-9_]+|i\/web)\/status\/\d+\/?$/.test(url.pathname)) return null;
        return `https://x.com${url.pathname.replace(/\/$/, "")}`;
      }
      if (!facebookHosts.has(url.hostname)) return null;
      if (/\/(?:posts|permalink)\/[\w.-]+\/?$/.test(url.pathname)) {
        return `https://www.facebook.com${url.pathname.replace(/\/$/, "")}`;
      }
      const post = url.searchParams.get("story_fbid");
      const owner = url.searchParams.get("id");
      if (["/story.php", "/permalink.php"].includes(url.pathname) && /^\w+$/.test(post ?? "") && /^\d+$/.test(owner ?? "")) {
        return `https://www.facebook.com/permalink.php?story_fbid=${post}&id=${owner}`;
      }
    } catch { /* Ignore unsupported or transient links. */ }
    return null;
  }

  function postLink(article) {
    if (!article) return null;
    const candidates = new Set();
    for (const anchor of article.querySelectorAll("a[href]")) {
      if (anchor.closest(articleSelector) !== article || (onX && !anchor.querySelector("time"))) continue;
      const url = permalink(anchor.href);
      if (url) candidates.add(url);
      if (candidates.size > 1) return null;
    }
    return candidates.values().next().value ?? null;
  }

  function observeConfirmation(confirmed, url) {
    watching = true;
    const page = location.href;
    let finished = false;
    const observer = new MutationObserver(check);
    const timeout = setTimeout(finish, 4500);
    function finish() {
      finished = true;
      observer.disconnect();
      clearTimeout(timeout);
      watching = false;
    }
    function check() {
      if (finished) return;
      if (page !== location.href || document.visibilityState !== "visible") return finish();
      if (!confirmed()) return;
      finish();
      void offer(url, page);
    }
    observer.observe(document.body, { subtree: true, childList: true, attributes: true,
      attributeFilter: ["data-testid", "aria-label", "hidden", "class", "style"], characterData: true });
    queueMicrotask(check);
  }

  async function offer(url, page) {
    try {
      if (!await chrome.runtime.sendMessage({ kind: "canOfferSiteSave" })) return;
    } catch { return; }
    showPrompt(page, "Add this post to Revisit?", async () => {
      const status = await chrome.runtime.sendMessage({ kind: "confirmSiteSave", url });
      return status?.startsWith("Draft sent")
        ? { close: true }
        : { message: status ?? "Open Revisit and try again." };
    });
  }

  function showPrompt(page, question, accept) {
    if (prompt || location.href !== page || document.visibilityState !== "visible") return false;
    const host = document.createElement("div");
    const root = host.attachShadow({ mode: "closed" });
    const style = document.createElement("style");
    style.textContent = `:host{all:initial;position:fixed;right:16px;top:16px;z-index:2147483647}
      section{box-sizing:border-box;width:min(320px,calc(100vw - 32px));background:#fff;color:#172c23;
      font:15px/1.45 system-ui;padding:16px;border:1px solid #60796e;border-radius:12px;
      box-shadow:0 4px 20px #0003;max-height:calc(100vh - 32px);overflow:auto} p{margin:0 0 10px}
      .bookmark{display:block;width:100%;text-align:left;margin:8px 0;overflow-wrap:anywhere}
      button{font:inherit;margin:0 8px 0 0;
      padding:6px 16px;border:1px solid #547568;border-radius:6px;background:#f0f7f3;color:#172c23;cursor:pointer}`;
    const panel = document.createElement("section");
    panel.setAttribute("aria-label", "Revisit bookmark prompt");
    const heading = document.createElement("p");
    heading.textContent = question;
    heading.setAttribute("role", "status");
    const yes = document.createElement("button");
    yes.textContent = "Yes";
    const no = document.createElement("button");
    no.textContent = "No";
    const close = () => {
      host.remove();
      clearTimeout(expiry);
      if (prompt === host) prompt = null;
    };
    no.addEventListener("click", event => { if (event.isTrusted) close(); });
    yes.addEventListener("click", async event => {
      if (!event.isTrusted || yes.disabled) return;
      if (location.href !== page) return close();
      yes.disabled = true;
      try {
        const result = await accept();
        if (!host.isConnected || location.href !== page) return close();
        if (result?.close) return close();
        if (result?.browse) {
          clearTimeout(expiry);
          yes.remove();
          no.textContent = "Close";
          heading.textContent = onX ? "Your X bookmarks" : "Your Facebook bookmarks";
          const list = document.createElement("div");
          const feedback = document.createElement("p");
          feedback.setAttribute("role", "status");
          const more = document.createElement("button");
          more.textContent = "Show more";
          const seen = new Set();
          let cursor = "";
          const live = () => host.isConnected && location.href === page;
          async function load() {
            more.disabled = true;
            feedback.textContent = "Loading bookmarks…";
            try {
              const reply = await chrome.runtime.sendMessage({ kind: "listBookmarks", cursor });
              if (!live()) return close();
              if (reply?.status !== "bookmarks" || !Array.isArray(reply.items) ||
                  !(reply.cursor === null || (typeof reply.cursor === "string" && /^[0-2]:[1-9][0-9]{0,14}$/.test(reply.cursor)))) throw Error();
              if (!reply.items.every(item => Number.isSafeInteger(item.id) && item.id > 0 &&
                  typeof item.title === "string" && [...item.title].length <= 200 &&
                  ["high", "medium", "low"].includes(item.priority))) throw Error();
              for (const item of reply.items) {
                if (seen.has(item.id)) continue;
                seen.add(item.id);
                const button = document.createElement("button");
                button.setAttribute("class", "bookmark");
                button.textContent = `${item.priority[0].toUpperCase() + item.priority.slice(1)} · ${item.title}`;
                button.addEventListener("click", async event => {
                  if (!event.isTrusted || button.disabled || !live()) return;
                  button.disabled = true;
                  try {
                    const opened = await chrome.runtime.sendMessage({ kind: "openBookmark", cursor: String(item.id) });
                    if (!live()) return close();
                    if (opened?.status !== "open") throw Error();
                    const url = new URL(opened.url);
                    if (!["https:", "http:"].includes(url.protocol) || url.username || url.password) throw Error();
                    close(); location.assign(url.href);
                  } catch {
                    feedback.textContent = "This bookmark could not open. It may have changed; check Revisit and try again.";
                    button.disabled = false;
                  }
                });
                list.append(button);
              }
              feedback.textContent = seen.size ? "Choose a bookmark to open its post." : "No active bookmarks for this site.";
              if (reply.cursor === null) more.remove();
              else if (reply.cursor === cursor) throw Error();
              else cursor = reply.cursor;
            } catch { feedback.textContent = "Could not load bookmarks. Keep Revisit running and try again."; }
            more.disabled = false;
          }
          more.addEventListener("click", event => { if (event.isTrusted && !more.disabled) void load(); });
          panel.append(list, feedback, more);
          await load();
          return;
        }
        if (result?.navigate) {
          close();
          location.assign(result.navigate);
          return;
        }
        heading.textContent = result?.message ?? "Revisit could not complete the request.";
        if (result?.done) {
          no.textContent = "Close";
          return;
        }
      } catch { heading.textContent = "Open Revisit and try again."; }
      yes.disabled = false;
    });
    panel.addEventListener("keydown", event => { if (event.key === "Escape") close(); });
    panel.append(heading, yes, no);
    root.append(style, panel);
    const expiry = setTimeout(close, 30000);
    prompt = host;
    document.body.append(host);
    return true;
  }

  chrome.runtime.onMessage.addListener((request, sender, respond) => {
    if (sender.id !== chrome.runtime.id || sender.tab) return false;
    if (request?.kind === "revisitReminderReady") {
      respond(!prompt && !watching && document.visibilityState === "visible");
    } else if (request?.kind === "revisitReminder") {
      let url;
      try { url = new URL(request.url); } catch { return false; }
      if (!["https:", "http:"].includes(url.protocol) || url.username || url.password) return false;
      respond(showPrompt(request.page, "You have saved bookmarks in Revisit. See them now?", () => ({ browse: true })));
    }
    return false;
  });

  function visibleSavedNotice() {
    return new Map([...document.querySelectorAll(liveSelector)]
      .filter(node => node.getClientRects().length)
      .map(node => [node, node.textContent.trim()])
      .filter(([, text]) => /^(?:post saved\.?|saved to (?:your )?saved items\.?)(?:\s+view(?: saved items)?)?$/i.test(text)));
  }

  document.addEventListener("click", event => {
    if (!event.isTrusted || watching || prompt || document.visibilityState !== "visible" ||
        !(event.target instanceof Element)) return;
    const target = event.target;
    if (onX) {
      const control = target.closest('[data-testid="bookmark"],button[aria-label="Bookmark"]');
      const article = control?.closest(articleSelector);
      const url = postLink(article);
      if (!url) return;
      observeConfirmation(() => article.isConnected && postLink(article) === url &&
        [...article.querySelectorAll('[data-testid="removeBookmark"],button[aria-label="Remove bookmark"]')]
          .some(button => button.closest(articleSelector) === article), url);
      return;
    }
    const menuButton = target.closest('[aria-label="Actions for this post"],[aria-label="More options"]');
    if (menuButton) {
      const url = postLink(menuButton.closest(articleSelector));
      pendingMenu = url ? { url, page: location.href, until: Date.now() + 15000 } : null;
      return;
    }
    const menuItem = target.closest('[role="menuitem"],[role="button"],button');
    const label = menuItem?.getAttribute("aria-label") ?? target.textContent.trim();
    const hasSaveLabel = label === "Save post" ||
      [...(menuItem?.querySelectorAll("span") ?? [])].some(span => span.textContent.trim() === "Save post");
    const menu = pendingMenu;
    pendingMenu = null;
    if (!menu || menu.until < Date.now() || menu.page !== location.href ||
        !menuItem?.closest('[role="menu"]') || !hasSaveLabel) return;
    const before = visibleSavedNotice();
    observeConfirmation(() => [...visibleSavedNotice()]
      .some(([node, text]) => before.get(node) !== text), menu.url);
  }, true);
})();
