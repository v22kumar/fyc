/* FYC finance — the bit every finance page shares.
 *
 * A treasurer collecting money stands in a hall with one bar of signal and a
 * queue of people in front of them. So the two things this file exists for are
 * (a) talking to the API with the headers the backend actually requires, and
 * (b) never losing an entry when the network drops mid-tap.
 *
 * Loaded as a plain script rather than a module: Astro treats a <script> with
 * define:vars as inline, which is the pattern the rest of this site uses, and
 * inline scripts cannot import. The page hands its config over on window.
 */
(function () {
  'use strict';

  var cfg = window.FYC_FINANCE_CONFIG || {};
  var API = cfg.apiBase || 'https://api.fycconnect.com';
  var ORG = cfg.orgId || '';
  var OUTBOX_KEY = 'fyc_finance_outbox';

  // ── Session ──────────────────────────────────────────────────────────────

  function token() { return localStorage.getItem('fyc_token'); }

  function user() {
    try { return JSON.parse(localStorage.getItem('fyc_user') || '{}'); }
    catch (e) { return {}; }
  }

  /** Send an unauthenticated visitor to sign in, and back here afterwards. */
  function requireAuth() {
    if (token()) return true;
    location.replace('/login?next=' + encodeURIComponent(location.pathname + location.search));
    return false;
  }

  function signOut() {
    ['fyc_token', 'fyc_user', 'fyc_role', 'fyc_refresh'].forEach(function (k) {
      localStorage.removeItem(k);
    });
    location.replace('/login?next=' + encodeURIComponent(location.pathname));
  }

  // ── The API ──────────────────────────────────────────────────────────────

  /* Errors carry the server's own sentence.
   *
   * The backend answers a repeated UTR with the row that already has it, and a
   * likely repeat with a question. Replacing either with "Something went
   * wrong" throws away the only part a treasurer can act on — so the parsed
   * body rides along on the error.
   */
  function ApiError(message, status, body) {
    var e = new Error(message);
    e.status = status;
    e.body = body;
    e.isApiError = true;
    return e;
  }

  function api(path, options) {
    options = options || {};
    var headers = {
      'X-Organization-ID': ORG,
      'Accept': 'application/json'
    };
    if (token()) headers['Authorization'] = 'Bearer ' + token();
    if (options.body) headers['Content-Type'] = 'application/json';

    // fetch has no timeout. On one bar of signal or behind a captive portal the
    // promise never settles, the save button sits on "Saving…", and the offline
    // path — which exists for exactly this network — never runs.
    var controller = window.AbortController ? new AbortController() : null;
    var timer = controller && setTimeout(function () { controller.abort(); },
                                         options.timeout || 20000);
    var done = function () { if (timer) clearTimeout(timer); };

    return fetch(API + '/api/v1' + path, {
      method: options.method || 'GET',
      headers: headers,
      body: options.body ? JSON.stringify(options.body) : undefined,
      signal: controller ? controller.signal : undefined
    }).catch(function (err) {
      done();
      throw err;                       // a dead network, not an API answer
    }).then(function (res) {
      done();
      if (res.status === 401) {
        signOut();
        throw ApiError('Your session has ended. Please sign in again.', 401, null);
      }
      var isJson = (res.headers.get('content-type') || '').indexOf('json') >= 0;
      return (isJson ? res.json() : res.text()).then(function (body) {
        if (res.ok) return body;
        var detail = body && body.detail;
        var message = typeof detail === 'string' ? detail
          : (detail && detail.detail) || 'That did not work. Please try again.';
        throw ApiError(message, res.status, detail);
      });
    });
  }

  // ── Money ────────────────────────────────────────────────────────────────

  /* 100000 → "1,00,000". `toLocaleString` with the wrong locale gives
   * "100,000", which is a different-looking number to everybody using this. */
  function groupIndian(whole) {
    var s = String(Math.abs(whole));
    if (s.length <= 3) return (whole < 0 ? '-' : '') + s;
    var last3 = s.slice(-3), rest = s.slice(0, -3), pairs = [];
    while (rest.length > 2) { pairs.unshift(rest.slice(-2)); rest = rest.slice(0, -2); }
    if (rest) pairs.unshift(rest);
    return (whole < 0 ? '-' : '') + pairs.join(',') + ',' + last3;
  }

  function money(paise) {
    paise = Math.round(Number(paise) || 0);
    var whole = Math.trunc(paise / 100), fraction = Math.abs(paise % 100);
    return '₹' + groupIndian(whole) + (fraction ? '.' + String(fraction).padStart(2, '0') : '');
  }

  // ── The outbox ───────────────────────────────────────────────────────────
  //
  // Straight out of the cricket scorer, for the same reason: an entry typed
  // while the signal is gone must survive the phone being locked, the tab
  // being closed, and the browser deciding to reclaim the page. Every entry
  // carries a client id generated before the network is involved, so a replay
  // that already landed is recorded once by the server rather than twice.

  function readOutbox() {
    try {
      var parsed = JSON.parse(localStorage.getItem(OUTBOX_KEY) || '[]');
      // A corrupted key would otherwise make findIndex and filter throw on
      // every call, which takes the whole page down rather than one entry.
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) { return []; }
  }

  /** True when the queue actually reached the disk. */
  function writeOutbox(items) {
    try {
      localStorage.setItem(OUTBOX_KEY, JSON.stringify(items));
      return true;
    } catch (e) {
      // Storage full, or a private-browsing mode that throws on access.
      // Swallowing this told the treasurer "saved on this phone" about an
      // entry that no longer existed anywhere — the one failure mode that
      // loses money silently.
      return false;
    }
  }

  function newClientId() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return 'c-' + Date.now() + '-' + Math.random().toString(36).slice(2, 10);
  }

  function enqueue(campaignId, body) {
    var items = readOutbox();
    items.push({
      campaign_id: campaignId,
      body: body,
      state: 'pending',
      queued_at: new Date().toISOString()
    });
    return writeOutbox(items) ? items : null;
  }

  var flushing = false;

  /* Drain the queue in order.
   *
   * In order matters less for correctness than for the treasurer's sanity: the
   * list they see should come back in the sequence they typed it. A single
   * failure stops the drain rather than skipping ahead, because a network that
   * just refused one request is about to refuse the next.
   */
  function flush(onChange) {
    if (flushing) return Promise.resolve();
    var items = readOutbox();
    var next = items.findIndex(function (i) { return i.state === 'pending'; });
    if (next < 0) return Promise.resolve();

    flushing = true;
    var item = items[next];
    return api('/finance/campaigns/' + item.campaign_id + '/contributions', {
      method: 'POST', body: item.body
    }).then(function (saved) {
      var all = readOutbox();
      // findIndex, and only splice on a hit. indexOf(find(...)) returns -1 when
      // the item has already gone — the treasurer pressed Remove while this
      // request was in flight, or a second tab drained the queue — and
      // splice(-1, 1) deletes the LAST entry instead: a different contribution,
      // not yet sent, gone for good.
      var at = all.findIndex(function (i) {
        return i.body.client_contribution_id === item.body.client_contribution_id;
      });
      if (at >= 0) {
        all.splice(at, 1);
        writeOutbox(all);
      }
      flushing = false;
      if (onChange) onChange({ saved: saved, remaining: all.length });
      return flush(onChange);
    }).catch(function (err) {
      var all = readOutbox();
      var mine = all.find(function (i) {
        return i.body.client_contribution_id === item.body.client_contribution_id;
      });
      if (mine) {
        if (err.isApiError && err.status === 409) {
          // The server wants a human answer. Park it rather than dropping it
          // or forcing it through — either would be us deciding.
          mine.state = 'conflict';
          mine.conflict = err.body;
        } else if (err.isApiError && err.status >= 400 && err.status < 500 &&
                   err.status !== 401 && err.status !== 403) {
          mine.state = 'rejected';
          mine.error = err.message;
        }
        // 401 and 403 stay pending. A session that expired mid-queue is a
        // sign-in away from working; marking the entry "refused by the server"
        // would leave the treasurer with nothing to press but Remove.
        // A 5xx or a dead network leaves it pending, to try again later.
        writeOutbox(all);
      }
      flushing = false;
      if (onChange) onChange({ error: err, remaining: readOutbox().length });
    });
  }

  function resolveConflict(clientId, keep) {
    var all = readOutbox();
    var item = all.find(function (i) { return i.body.client_contribution_id === clientId; });
    if (!item) return;
    if (keep) {
      item.body.confirm_duplicate = true;
      item.state = 'pending';
      delete item.conflict;
    } else {
      all.splice(all.indexOf(item), 1);
    }
    writeOutbox(all);
  }

  function discard(clientId) {
    var all = readOutbox().filter(function (i) {
      return i.body.client_contribution_id !== clientId;
    });
    writeOutbox(all);
  }

  function pendingCount() {
    return readOutbox().filter(function (i) { return i.state === 'pending'; }).length;
  }

  // ── Small helpers every page repeats otherwise ───────────────────────────

  /* Safe in an attribute, not only in a text node.
   *
   * The textContent round-trip this used to do escapes &, < and > and leaves
   * both quote characters alone — which is fine for `<span>NAME</span>` and an
   * injection point for `data-name="NAME"`, which is how these pages carry a
   * contributor into a button. A treasurer types the contributor's name, so
   * the name is untrusted input by definition.
   */
  function esc(text) {
    return String(text == null ? '' : text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function ago(iso) {
    if (!iso) return '';
    // A server that serialises "2026-08-12T10:00:00" with no offset means UTC,
    // but `new Date` reads it as local — five and a half hours out in IST,
    // which reads as a future timestamp and makes everything say "just now".
    var text = String(iso);
    if (!/[zZ]|[+-]\d{2}:?\d{2}$/.test(text)) text += 'Z';
    var seconds = (Date.now() - new Date(text).getTime()) / 1000;
    if (seconds < 60) return 'just now';
    if (seconds < 3600) return Math.floor(seconds / 60) + ' min ago';
    if (seconds < 86400) return Math.floor(seconds / 3600) + ' h ago';
    return new Date(iso).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  }

  function today() {
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') +
           '-' + String(d.getDate()).padStart(2, '0');
  }

  /* One word per status, shared, because two screens invented two.
   *
   * The database calls an unverified contribution RECORDED — correct, somebody
   * recorded it. To the people using this it is *pending*. */
  function statusWord(status) {
    return status === 'RECORDED' ? 'Pending'
      : String(status || '').charAt(0) + String(status || '').slice(1).toLowerCase();
  }

  var toastTimer = null;
  function toast(message, ms) {
    var host = document.getElementById('toast');
    var body = document.getElementById('toast-body');
    if (!host || !body) return;
    body.textContent = message;
    host.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { host.classList.add('hidden'); }, ms || 2600);
  }

  /* Dialogs that a keyboard can leave.
   *
   * All four of these open by toggling a class. Without this, focus stays on
   * the page behind the overlay and Escape does nothing, so a dialog asking
   * "is this the same payment?" is unanswerable without a pointer.
   */
  var focusBeforeDialog = null;

  function openDialog(id, focusId) {
    var el = document.getElementById(id);
    if (!el) return;
    focusBeforeDialog = document.activeElement;
    el.classList.remove('hidden');
    el.classList.add('flex');
    var target = focusId && document.getElementById(focusId);
    if (target) setTimeout(function () { target.focus(); }, 30);
  }

  function closeDialog(id) {
    var el = document.getElementById(id);
    if (!el) return;
    el.classList.add('hidden');
    el.classList.remove('flex');
    if (focusBeforeDialog && focusBeforeDialog.focus) focusBeforeDialog.focus();
    focusBeforeDialog = null;
  }

  /** Escape closes whichever dialog is open, and runs its cancel behaviour. */
  function dismissDialogsOnEscape(handlers) {
    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      Object.keys(handlers).forEach(function (id) {
        var el = document.getElementById(id);
        if (el && !el.classList.contains('hidden')) handlers[id]();
      });
    });
  }

  window.FYC = {
    api: api, token: token, user: user, requireAuth: requireAuth, signOut: signOut,
    money: money, groupIndian: groupIndian,
    enqueue: enqueue, flush: flush, readOutbox: readOutbox, pendingCount: pendingCount,
    resolveConflict: resolveConflict, discard: discard, newClientId: newClientId,
    esc: esc, ago: ago, today: today, statusWord: statusWord, toast: toast,
    openDialog: openDialog, closeDialog: closeDialog,
    dismissDialogsOnEscape: dismissDialogsOnEscape
  };
})();
