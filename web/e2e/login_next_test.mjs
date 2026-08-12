/**
 * ?next is where a treasurer comes back to. It must not be a way out.
 *
 * The finance pages send an unauthenticated visitor to /login?next=/finance and
 * rely on being returned. That makes this parameter load-bearing — and a login
 * page that redirects wherever a link tells it to is a phishing tool: the
 * victim sees the club's own domain, signs in for real, and lands somewhere
 * else, having just been taught that the link is safe.
 *
 *   node e2e/login_next_test.mjs
 */
import { existsSync } from 'node:fs';
import { chromium } from 'playwright';

const WEB = process.env.E2E_WEB_BASE || 'http://127.0.0.1:4321';

function browserPath() {
  for (const c of [process.env.E2E_CHROMIUM, '/opt/pw-browsers/chromium']) {
    if (c && existsSync(c)) return c;
  }
  return undefined;
}

/* Where the browser came to rest.
 *
 * An inline script decides where to go, so there is no navigation for `goto`
 * to await. Two earlier attempts were both wrong in instructive ways: a fixed
 * 600 ms sleep passed here and lost the race on a loaded CI runner, and
 * waiting for "no longer on /login" caught the *middle* of a journey — an
 * expired session goes login → finance → login, and the check fired on the
 * hop through finance.
 *
 * So: wait for the URL to stop changing. A late redirect resets the clock,
 * which is what makes this adapt to a slow machine instead of guessing at one.
 */
async function settledUrl(page, { quiet = 700, timeout = 20000 } = {}) {
  const deadline = Date.now() + timeout;
  let last = page.url();
  let since = Date.now();
  while (Date.now() < deadline) {
    await page.waitForTimeout(100);
    const now = page.url();
    if (now !== last) {
      last = now;
      since = Date.now();
    } else if (Date.now() - since >= quiet) {
      return last;
    }
  }
  return page.url();
}

let failures = 0;
const check = (what, ok, detail = '') => {
  if (ok) console.log(`  ✓ ${what}`);
  else { failures++; console.error(`  ✗ ${what}\n    ${detail}`); }
};

const browser = await chromium.launch({ executablePath: browserPath() });

/** Land on /login already carrying a session, and see where it throws us. */
async function landsAt(next, { signedIn = true } = {}) {
  const context = await browser.newContext();
  if (signedIn) {
    await context.addInitScript(() => {
      localStorage.setItem('fyc_token', 'not-a-real-token');
      localStorage.setItem('fyc_user', '{}');
    });
  }
  const page = await context.newPage();
  // The destinations under test are off-site; never actually go there.
  await context.route('**://evil.example/**', (route) =>
    route.fulfill({ status: 200, body: 'off-site' }));
  await page.goto(`${WEB}/login?next=${encodeURIComponent(next)}`,
                  { waitUntil: 'domcontentloaded' });

  const url = await settledUrl(page);
  await context.close();
  return url;
}

console.log('\nWhere ?next is allowed to send somebody');

/* Aimed at a page that does not call the API.
 *
 * Pointing it at /finance tested something else by accident: the session here
 * is a made-up token, so the finance page loads, gets a 401, signs the visitor
 * out and sends them back to /login — which is correct behaviour and says
 * nothing about the redirect rule. It is also, usefully, proof that an expired
 * session lands on the sign-in form rather than in a loop.
 */
const ordinary = await landsAt('/about');
check('an ordinary path is honoured — this is what finance depends on',
  /\/about/.test(ordinary), `landed at ${ordinary}`);

/* Signed out, not signed-in-with-a-dead-token.
 *
 * This asserted the expired-session case, which reaches /finance, waits for the
 * API to answer 401, and only then bounces back to /login. That made a test of
 * a client-side redirect rule depend on a backend round-trip, and it timed out
 * twice on CI — once at a full twenty seconds, having never left /finance.
 *
 * Signed out exercises the property that matters to the finance pages — a
 * visitor is sent to sign in and brought back — through requireAuth alone, with
 * no request in the loop at all.
 */
const sentAway = await landsAt('/finance', { signedIn: false });
check('a signed-out visitor is sent to sign in, and told where to return',
  /\/login/.test(sentAway) && /next=%2Ffinance/.test(sentAway),
  `landed at ${sentAway}`);

for (const hostile of [
  'https://evil.example/phish',
  '//evil.example/phish',
  '\\\\evil.example/phish',
]) {
  const landed = await landsAt(hostile);
  check(`${hostile} is refused, and lands on the club's own home page`,
    !/evil\.example/.test(landed), `landed at ${landed}`);
}

await browser.close();
console.log(failures === 0 ? '\nThe way back is only ever into this site. ✓'
                           : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
