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

let failures = 0;
const check = (what, ok, detail = '') => {
  if (ok) console.log(`  ✓ ${what}`);
  else { failures++; console.error(`  ✗ ${what}\n    ${detail}`); }
};

const browser = await chromium.launch({ executablePath: browserPath() });

/** Land on /login already carrying a session, and see where it throws us. */
async function landsAt(next) {
  const context = await browser.newContext();
  await context.addInitScript(() => {
    localStorage.setItem('fyc_token', 'not-a-real-token');
    localStorage.setItem('fyc_user', '{}');
  });
  const page = await context.newPage();
  // The destinations under test are off-site; never actually go there.
  await context.route('**://evil.example/**', (route) =>
    route.fulfill({ status: 200, body: 'off-site' }));
  await page.goto(`${WEB}/login?next=${encodeURIComponent(next)}`,
                  { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(600);
  const url = page.url();
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

const expired = await landsAt('/finance');
check('an expired session lands on the sign-in form, not in a loop',
  /\/login/.test(expired) && /next=%2Ffinance/.test(expired),
  `landed at ${expired}`);

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
