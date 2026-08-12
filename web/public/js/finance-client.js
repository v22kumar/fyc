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

    return fetch(API + '/api/v1' + path, {
      method: options.method || 'GET',
      headers: headers,
      body: options.body ? JSON.stringify(options.body) : undefined
    }).then(function (res) {
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
    try { return JSON.parse(localStorage.getItem(OUTBOX_KEY) || '[]'); }
    catch (e) { return []; }
  }

  function writeOutbox(items) {
    try { localStorage.setItem(OUTBOX_KEY, JSON.stringify(items)); } catch (e) {}
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
    writeOutbox(items);
    return items;
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
      all.splice(all.indexOf(all.find(function (i) {
        return i.body.client_contribution_id === item.body.client_contribution_id;
      })), 1);
      writeOutbox(all);
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
        } else if (err.isApiError && err.status >= 400 && err.status < 500) {
          mine.state = 'rejected';
          mine.error = err.message;
        }
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

  function esc(text) {
    var d = document.createElement('div');
    d.textContent = text == null ? '' : String(text);
    return d.innerHTML;
  }

  function ago(iso) {
    if (!iso) return '';
    var seconds = (Date.now() - new Date(iso).getTime()) / 1000;
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

  window.FYC = {
    api: api, token: token, user: user, requireAuth: requireAuth, signOut: signOut,
    money: money, groupIndian: groupIndian,
    enqueue: enqueue, flush: flush, readOutbox: readOutbox, pendingCount: pendingCount,
    resolveConflict: resolveConflict, discard: discard, newClientId: newClientId,
    esc: esc, ago: ago, today: today
  };
})();
