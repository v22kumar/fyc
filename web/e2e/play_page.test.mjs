/**
 * End-to-end browser test of the /play board.
 *
 * Drives a real Chromium against a real backend, with the opponent playing over
 * a plain WebSocket exactly as the Android client does. This is the test that
 * catches the class of bug unit tests structurally cannot: a move that leaves
 * the board in the wrong coordinates, a socket that stalls mid-game, a page
 * that throws before it ever renders.
 *
 * Config arrives as one JSON argument (see scripts/e2e/seed_e2e_games.py):
 *   node play_page.test.mjs '{"game_id":"…","web_token":"…","opp_token":"…"}'
 *
 * Exits non-zero if any check fails, so CI can gate on it.
 */
import { chromium } from 'playwright';
import WebSocket from 'ws';

const cfg = JSON.parse(process.argv[2]);
const WEB = process.env.E2E_WEB_BASE || 'http://127.0.0.1:4321';
const API_WS = process.env.E2E_WS_BASE || 'ws://127.0.0.1:8000';

const ok = [];
const bad = [];
const check = (name, pass, detail = '') =>
  (pass ? ok : bad).push(`${pass ? '✓' : '✗'} ${name}${detail ? ' — ' + detail : ''}`);

// The opponent speaks the raw protocol from the other side of the wire.
const opp = new WebSocket(
  `${API_WS}/api/v1/chess/games/${cfg.game_id}/ws?token=${cfg.opp_token}`,
);
const oppSaw = [];
opp.on('message', (raw) => {
  try { oppSaw.push(JSON.parse(raw.toString())); } catch { /* non-JSON frame */ }
});
await new Promise((r, j) => { opp.on('open', r); opp.on('error', j); });

// E2E_CHROMIUM points at a browser that is already on the machine, for
// environments that ship one rather than letting Playwright download its own.
const browser = await chromium.launch(
  process.env.E2E_CHROMIUM ? { executablePath: process.env.E2E_CHROMIUM } : {},
);
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
// Requests that never completed, with their URL — "failed to load resource"
// on its own is not enough to tell a broken page from a blocked CDN.
const failedRequests = [];
page.on('requestfailed', (r) => failedRequests.push(`${r.url()} (${r.failure()?.errorText})`));

// Seed the session the way a signed-in visitor would have it.
await page.addInitScript((t) => localStorage.setItem('fyc_token', t), cfg.web_token);
await page.goto(`${WEB}/play/?game=${cfg.game_id}`, { waitUntil: 'networkidle' });

// ── 1. the board renders ────────────────────────────────────────────────────
await page.waitForSelector('cg-board', { timeout: 15000 });
const pieces = await page.locator('cg-board piece').count();
check('board renders with 32 pieces', pieces === 32, `${pieces} found`);

const bottomName = (await page.locator('#bot-name').textContent())?.trim();
check('player sees their own name at the bottom',
      bottomName === cfg.home_name, bottomName);

// ── 2. the clock is real ────────────────────────────────────────────────────
const clock1 = (await page.locator('#bot-clock').textContent())?.trim();
check('clock shows the 10-minute control', /^(10:00|9:5\d)$/.test(clock1 || ''), clock1);
await page.waitForTimeout(1800);
const clock2 = (await page.locator('#bot-clock').textContent())?.trim();
check('clock is ticking down', clock1 !== clock2, `${clock1} → ${clock2}`);

// ── 3. a dragged move reaches the server ────────────────────────────────────
// Dragged with the real mouse, not dispatched as a synthetic event: the bug
// this guards against was a coordinate flip that only a real drag reproduces.
const box = await page.locator('cg-board').boundingBox();
const sq = (file, rank) => ({          // white orientation: a1 bottom-left
  x: box.x + (file + 0.5) * (box.width / 8),
  y: box.y + (7 - rank + 0.5) * (box.height / 8),
});
const from = sq(4, 1);   // e2
const to = sq(4, 3);     // e4
await page.mouse.move(from.x, from.y);
await page.mouse.down();
await page.mouse.move(to.x, to.y, { steps: 12 });
await page.mouse.up();

await page.waitForTimeout(1500);
const oppGotE4 = oppSaw.some((m) => m.type === 'move' && m.uci === 'e2e4');
check('drag on the web board reached the server', oppGotE4,
      oppGotE4 ? 'opponent received e2e4'
               : `opponent saw ${JSON.stringify(oppSaw.map((m) => m.type + (m.uci ? ':' + m.uci : '')))}`);

const movesText = (await page.locator('#moves').textContent()) || '';
check('move list shows the SAN', movesText.includes('e4'), movesText.trim().slice(0, 40));

// ── 4. the opponent's move appears on the web board ─────────────────────────
opp.send(JSON.stringify({ type: 'move', uci: 'e7e5' }));
await page.waitForFunction(
  () => (document.getElementById('moves')?.textContent || '').includes('e5'),
  { timeout: 10000 },
).catch(() => { /* checked below with a real assertion */ });
const movesText2 = (await page.locator('#moves').textContent()) || '';
check("opponent's move appears on the web board", movesText2.includes('e5'),
      movesText2.trim().slice(0, 40));

// ── 5. the game ends on screen ──────────────────────────────────────────────
opp.send(JSON.stringify({ type: 'resign' }));
await page.waitForSelector('#over:not(.hidden)', { timeout: 10000 }).catch(() => {});
check('game-over curtain appears', await page.locator('#over').isVisible());
const overTitle = (await page.locator('#over-title').textContent())?.trim();
check('result is shown from the player’s point of view',
      overTitle === 'You won', overTitle);

// A failed fetch of a third-party asset is a fact about the network, not about
// our code; a script that threw is always ours.
const scriptErrors = errors.filter((e) => !/Failed to load resource/i.test(e));
check('no uncaught JS errors', scriptErrors.length === 0, scriptErrors.slice(0, 2).join(' | '));

// Anything the page fetches from outside our own origins is a request that can
// fail on a member's connection. Webfonts are excused — they degrade to the
// device's own faces — but a call to a different backend is a bug: it means
// part of the page ignores the API base it was built with, and this test found
// exactly that (a header widget hardcoded to production).
if (failedRequests.length) console.log('  (requests that failed: ' + failedRequests.join(', ') + ')');
const foreignFailures = failedRequests.filter(
  (u) => !u.startsWith(WEB)
      && !u.startsWith('http://127.0.0.1')
      && !/fonts\.(googleapis|gstatic)\.com/.test(u));
check('every backend call goes to the API base the site was built with',
      foreignFailures.length === 0, foreignFailures.slice(0, 2).join(' | '));

await browser.close();
opp.close();

console.log('\n' + ok.join('\n'));
if (bad.length) console.log('\n' + bad.join('\n'));
console.log(`\n${ok.length} passed, ${bad.length} failed`);
process.exit(bad.length ? 1 : 0);
