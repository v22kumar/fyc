/**
 * Can a treasurer actually record money?
 *
 * Everything else in this module is tested against the API. This is the only
 * test that answers the question the club actually asked, which is whether a
 * person holding a phone can open a link and enter a contribution — through
 * the real pages, a real browser, and a real backend.
 *
 * It runs as two people, deliberately:
 *
 *   Kumar is a club official. He creates the collection and appoints Arun.
 *   Arun is an ordinary member. Before Kumar appoints him he can do nothing;
 *   afterwards he holds the club's money, so what he records is the record —
 *   and what Kumar records waits for Arun to confirm it arrived.
 *
 * Seeding Arun as an admin would make every assertion here pass while proving
 * nothing about the permission model.
 *
 *   node e2e/finance_page.test.mjs '<seed json>'
 */
import { existsSync } from 'node:fs';
import { chromium } from 'playwright';

const WEB = process.env.E2E_WEB_BASE || 'http://127.0.0.1:4321';
const seed = JSON.parse(process.argv[2] || '{}');
if (!seed.org_id || !seed.admin?.token || !seed.treasurer?.token) {
  console.error('Pass the JSON from scripts/e2e/seed_finance_e2e.py as argv[2].');
  process.exit(1);
}

/* Where the browser actually is.
 *
 * Playwright looks for a build number matched to its own version, and CI
 * images pin a browser independently of the package. When the two disagree the
 * error is "run npx playwright install", which on an image with no network is
 * a dead end — so prefer an explicitly provided binary when one exists.
 */
function browserPath() {
  for (const candidate of [process.env.E2E_CHROMIUM, '/opt/pw-browsers/chromium']) {
    if (candidate && existsSync(candidate)) return candidate;
  }
  return undefined;   // let Playwright resolve it the usual way
}

let failures = 0;
const pass = (what) => console.log(`  ✓ ${what}`);
const fail = (what, detail) => {
  failures++;
  console.error(`  ✗ ${what}\n    ${detail}`);
};

function check(what, condition, detail = '') {
  condition ? pass(what) : fail(what, detail);
}

/** Open a page already signed in as this person, the way the app does it. */
async function signedInPage(browser, person, path) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },     // a phone, because that is the tool
    deviceScaleFactor: 2,
  });
  await context.addInitScript(({ token, user }) => {
    localStorage.setItem('fyc_token', token);
    localStorage.setItem('fyc_user', JSON.stringify(user));
    localStorage.setItem('fyc_role', user.role);
  }, { token: person.token, user: { id: person.id, full_name_en: person.name, role: person.role } });

  const page = await context.newPage();
  const problems = [];
  const traffic = [];
  page.on('console', (m) => {
    // The browser logs every non-2xx as a console error. A 409 here is the
    // duplicate guard doing its job — counting it as a page fault would mean
    // the test fails precisely when the feature works.
    // The browser logs every non-2xx as a console error, and its message for a
    // failed subresource does not always carry the URL — so this can only key
    // on the status. 409 is the duplicate guard doing its job; the backend
    // test suite pins that code, so a change there fails loudly elsewhere
    // rather than quietly widening what this ignores.
    if (m.type() === 'error' && !/status of 409/.test(m.text())) problems.push(m.text());
  });
  page.on('pageerror', (e) => problems.push(String(e)));
  page.on('requestfailed', (r) => problems.push(`request failed: ${r.url()} — ${r.failure()?.errorText}`));
  page.on('response', (r) => {
    if (r.url().includes('/api/')) traffic.push(`${r.status()} ${r.url().split('/api/v1')[1]}`);
  });
  await page.goto(WEB + path, { waitUntil: 'networkidle' });

  /* Wait, and if it never happens, say what the browser saw.
   *
   * A bare Playwright timeout names the selector and nothing else, which for a
   * page whose state comes entirely from API calls is the least useful half of
   * the story. */
  page.waitForOr = async (selector, timeout = 15000) => {
    try {
      await page.waitForSelector(selector, { timeout });
      return true;
    } catch (e) {
      console.error(`    waited for ${selector} and it never came.`);
      console.error(`    API calls: ${traffic.join(' | ') || '(none)'}`);
      console.error(`    console:   ${problems.join(' | ') || '(clean)'}`);
      const shown = await page.evaluate(() => {
        const out = {};
        ['loading', 'empty', 'page', 'denied'].forEach((id) => {
          const el = document.getElementById(id);
          if (el) out[id] = el.classList.contains('hidden') ? 'hidden' : 'shown';
        });
        const empty = document.getElementById('empty');
        out.text = empty ? empty.innerText.replace(/\s+/g, ' ').slice(0, 160) : '';
        return out;
      });
      console.error(`    on screen: ${JSON.stringify(shown)}`);
      return false;
    }
  };
  return { context, page, problems };
}

async function main() {
  const browser = await chromium.launch({ executablePath: browserPath() });

  // ── Arun, before anybody has appointed him ───────────────────────────────
  console.log('\nArun, an ordinary member, before he is appointed');
  {
    const { context, page } = await signedInPage(browser, seed.treasurer, '/finance');
    await page.waitForSelector('#empty:not(.hidden), #page:not(.hidden)', { timeout: 15000 });
    const isEmpty = await page.isVisible('#empty');
    check('sees an explanation, not a form or an error',
      isEmpty, 'the entry form was reachable by somebody with no appointment');
    if (isEmpty) {
      const words = await page.textContent('#empty h2');
      check('and the explanation says what has to happen next',
        /no collection assigned/i.test(words), `heading read: ${words}`);
    }
    await context.close();
  }

  // ── Kumar sets the collection up ─────────────────────────────────────────
  console.log('\nKumar, a club official, sets up the anniversary');
  let collectionCreated = false;
  {
    const { context, page, problems } = await signedInPage(browser, seed.admin, '/finance/admin');
    await page.waitForSelector('#page:not(.hidden)', { timeout: 15000 });

    check('lands on the first-run screen when nothing exists yet',
      await page.isVisible('#first-run'), 'expected the create-a-collection prompt');

    await page.click('#first-run-open');
    await page.waitForSelector('#sheet.flex', { timeout: 5000 });

    check('the form arrives pre-filled with the planned amount per head',
      (await page.inputValue('#f-suggested')) === '3500',
      `planned per head read: ${await page.inputValue('#f-suggested')}`);
    check('and with no target, because the club has not set one',
      (await page.inputValue('#f-target')) === '',
      'a target was pre-filled that nobody asked for');

    await page.fill('#f-title', 'FYC Anniversary Celebration 2026');
    await page.fill('#f-title-ta', 'எஃப்ஒய்சி ஆண்டு விழா 2026');
    await page.click('#sheet-save');

    await page.waitForSelector('#summary-card:not(.hidden)', { timeout: 15000 });
    collectionCreated = true;
    pass('the collection is created and the dashboard opens on it');

    const title = await page.textContent('#c-title');
    check('named as typed', /Anniversary Celebration 2026/.test(title), `read: ${title}`);
    check('no progress bar, because there is no target to be a fraction of',
      await page.isHidden('#target-row'),
      'a progress bar appeared for a collection with no target');

    // Appoint Arun.
    await page.click('#add-treasurer');
    await page.waitForSelector('#pick.flex', { timeout: 5000 });
    await page.fill('#pick-search', 'Arun');
    await page.waitForSelector('#pick-list [data-appoint]', { timeout: 10000 });
    await page.click('#pick-list [data-appoint]');
    await page.waitForSelector('#treasurers [data-revoke]', { timeout: 10000 });
    const appointed = await page.textContent('#treasurers');
    check('Arun — and not whoever happened to be first in the list — is appointed',
      /Arun Treasurer/.test(appointed), `treasurers read: ${appointed.replace(/\s+/g, ' ')}`);

    check('no page errors along the way', problems.length === 0, problems.join('\n    '));
    await page.screenshot({ path: 'e2e-finance-admin-empty.png', fullPage: true });
    await context.close();
  }

  if (!collectionCreated) {
    console.error('\nNo collection was created — the rest cannot be judged.');
    process.exit(1);
  }

  // ── Arun collects ────────────────────────────────────────────────────────
  console.log('\nArun records the evening’s contributions');
  {
    const { context, page, problems } = await signedInPage(browser, seed.treasurer, '/finance');
    if (!(await page.waitForOr('#page:not(.hidden)'))) {
      fail('the collection is now his to record against', 'the entry page never opened');
      await context.close();
      await browser.close();
      process.exit(1);
    }
    pass('the collection is now his to record against');

    check('the planned amount is offered as one tap',
      await page.isVisible('#amount-chips button'), 'no quick amounts were offered');
    const chip = await page.textContent('#amount-chips button');
    check('and it is the ₹3,500 the club planned, marked as such',
      /₹3,500/.test(chip) && /planned/.test(chip), `first chip read: ${chip}`);

    // The fast path: tap the planned amount, type a name, save.
    await page.click('#amount-chips button');
    check('tapping it fills the amount, grouped the Indian way',
      (await page.inputValue('#amount')) === '3,500',
      `amount field read: ${await page.inputValue('#amount')}`);

    await page.fill('#who', 'Ravi Kumar');
    await page.fill('#phone', '9487984964');
    await page.click('#save');
    await page.waitForSelector('#toast:not(.hidden)', { timeout: 15000 });
    const toast = await page.textContent('#toast-body');
    check('saving confirms with the amount and the name',
      /₹3,500/.test(toast) && /Ravi Kumar/.test(toast), `confirmation read: ${toast}`);

    check('and clears the person so the next one can be typed straight away',
      (await page.inputValue('#who')) === '' && (await page.inputValue('#amount')) === '',
      'the form kept the previous person');

    await page.waitForFunction(
      () => /3,500/.test(document.getElementById('my-total').textContent), null,
      { timeout: 15000 });
    pass('the running total moves without a reload');

    // A second person, a different amount, paying by UPI.
    await page.click('#methods [data-method="UPI"]');
    check('choosing UPI reveals the reference field',
      await page.isVisible('#reference-wrap'), 'the reference field stayed hidden for UPI');

    await page.fill('#amount', '5000');
    await page.fill('#who', 'Meena');
    await page.fill('#reference', 'UTR123456');
    await page.click('#save');
    await page.waitForFunction(
      () => /8,500/.test(document.getElementById('my-total').textContent), null,
      { timeout: 15000 });
    pass('a second contribution lands and the total reads ₹8,500');

    // The same UTR again. This one is never legitimate.
    await page.fill('#amount', '1000');
    await page.fill('#who', 'Somebody Else');
    await page.fill('#reference', 'UTR123456');
    await page.click('#save');
    await page.waitForSelector('#form-error:not(.hidden)', { timeout: 15000 });
    const refused = await page.textContent('#form-error');
    check('the same UTR twice is refused, naming what already has it',
      /UTR123456/i.test(refused) && /Meena/.test(refused), `message read: ${refused}`);

    // The same person, the same amount, moments later. This one is a question.
    await page.click('#methods [data-method="CASH"]');
    await page.fill('#amount', '3,500');
    await page.fill('#who', 'Ravi Kumar');
    await page.fill('#phone', '9487984964');
    await page.click('#save');
    await page.waitForSelector('#dupe.flex', { timeout: 15000 });
    const asked = await page.textContent('#dupe-message');
    check('a likely repeat is asked about, not refused',
      /Ravi Kumar/.test(asked) && /same payment/i.test(asked), `question read: ${asked}`);

    await page.screenshot({ path: 'e2e-finance-duplicate.png', fullPage: true });

    await page.click('#dupe-confirm');   // "No — add it"
    await page.waitForFunction(
      () => /12,000/.test(document.getElementById('my-total').textContent), null,
      { timeout: 15000 });
    pass('confirming it is a different payment records it — total ₹12,000');

    // Nothing to confirm: everything on this page is his own, and his own
    // entries are the record the moment he writes them.
    check('a treasurer is not asked to confirm their own money',
      await page.isHidden('#confirm'),
      'the confirm queue appeared for a treasurer’s own entries');
    const first = await page.textContent('#entries');
    check('and those entries read as verified straight away',
      /Verified/.test(first), `entries read: ${first.replace(/\s+/g, ' ').slice(0, 120)}`);

    await page.screenshot({ path: 'e2e-finance-treasurer.png', fullPage: true });
    check('no page errors along the way', problems.length === 0, problems.join('\n    '));
    await context.close();
  }

  // ── Offline, which is the normal case in a hall ──────────────────────────
  console.log('\nArun, when the signal goes');
  {
    const { context, page } = await signedInPage(browser, seed.treasurer, '/finance');
    await page.waitForSelector('#page:not(.hidden)', { timeout: 15000 });

    await context.setOffline(true);
    await page.fill('#amount', '2000');
    await page.fill('#who', 'Selvi');
    await page.click('#save');

    await page.waitForSelector('#outbox:not(.hidden)', { timeout: 15000 });
    const queued = await page.textContent('#outbox-list');
    check('the entry is kept on the phone and says so',
      /Selvi/.test(queued) && /₹2,000/.test(queued), `queue read: ${queued}`);
    check('and the form clears, so collecting can carry on',
      (await page.inputValue('#who')) === '', 'the form blocked on a dead network');

    await page.screenshot({ path: 'e2e-finance-offline.png', fullPage: true });

    // Signal returns.
    await context.setOffline(false);
    await page.evaluate(() => window.dispatchEvent(new Event('online')));
    await page.waitForFunction(
      () => document.getElementById('outbox').classList.contains('hidden'), null,
      { timeout: 20000 });
    pass('when the signal returns the queue drains by itself');

    await page.waitForFunction(
      () => /14,000/.test(document.getElementById('my-total').textContent), null,
      { timeout: 15000 });
    pass('and the total picks it up — ₹14,000');
    await context.close();
  }

  // ── Kumar hands money in, and Arun confirms it arrived ───────────────────
  console.log('\nKumar hands over money he collected himself');
  {
    const { context, page } = await signedInPage(browser, seed.admin, '/finance');
    await page.waitForSelector('#page:not(.hidden)', { timeout: 15000 });
    await page.fill('#amount', '1000');
    await page.fill('#who', 'Anbu');
    await page.click('#save');
    await page.waitForSelector('#toast:not(.hidden)', { timeout: 15000 });
    pass('an official can record too');

    // The list refreshes after the save, so wait for the row rather than
    // reading whatever was on screen when the toast appeared.
    await page.waitForFunction(
      () => /Anbu/.test(document.getElementById('entries').textContent), null,
      { timeout: 15000 });
    const rows = await page.textContent('#entries');
    check('but their entry is a claim, not the record',
      /Pending/.test(rows), `entries read: ${rows.replace(/\s+/g, ' ').slice(0, 120)}`);
    await context.close();
  }

  console.log('\nArun confirms what reached him');
  {
    const { context, page } = await signedInPage(browser, seed.treasurer, '/finance');
    await page.waitForSelector('#confirm:not(.hidden)', { timeout: 15000 });
    const queue = await page.textContent('#confirm-list');
    check('it is waiting on the person who holds the cash',
      /Anbu/.test(queue) && /₹1,000/.test(queue),
      `queue read: ${queue.replace(/\s+/g, ' ').slice(0, 140)}`);

    await page.click('#confirm-list [data-confirm]');
    await page.waitForFunction(
      () => document.getElementById('confirm').classList.contains('hidden'), null,
      { timeout: 15000 });
    pass('confirming it clears the queue');
    await context.close();
  }

  // ── Kumar reads the dashboard ────────────────────────────────────────────
  console.log('\nKumar checks the evening’s money');
  {
    const { context, page, problems } = await signedInPage(browser, seed.admin, '/finance/admin');
    await page.waitForSelector('#summary-card:not(.hidden)', { timeout: 15000 });

    const collected = await page.textContent('#collected');
    check('the dashboard shows everything taken', /15,000/.test(collected),
      `collected read: ${collected}`);

    const verified = await page.textContent('#verified');
    check('and all of it is verified, because the treasurer took or confirmed it',
      /15,000/.test(verified), `verified read: ${verified}`);

    // The treasurer breakdown should attribute everything to Arun.
    await page.click('.tab[data-by="treasurer"]');
    await page.waitForSelector('#breakdown div', { timeout: 10000 });
    const breakdown = await page.textContent('#breakdown');
    check('the breakdown names who collected it', /Arun Treasurer/.test(breakdown),
      `breakdown read: ${breakdown.slice(0, 160)}`);

    // Setting a target turns the bar on.
    await page.click('#edit-campaign');
    await page.waitForSelector('#sheet.flex', { timeout: 5000 });
    await page.fill('#f-target', '100000');

    /* Wait for the reload, not for a selector.
     *
     * Saving ends in location.reload(). `#summary-card` is *already* visible
     * at this point, so waiting for it matches the old DOM immediately and the
     * next assertion races the navigation — which is exactly how this failed
     * once and passed the next run. The create-a-collection save above is safe
     * from the same trap only because the card is hidden until it succeeds.
     */
    const reloaded = page.waitForEvent('load');
    await page.click('#sheet-save');
    await reloaded;

    await page.waitForSelector('#summary-card:not(.hidden)', { timeout: 20000 });
    await page.waitForFunction(
      () => !document.getElementById('target-row').classList.contains('hidden'), null,
      { timeout: 15000 });
    const target = await page.textContent('#target-line');
    check('setting a target turns on the progress line', /₹1,00,000/.test(target),
      `target line read: ${target}`);

    await page.screenshot({ path: 'e2e-finance-admin.png', fullPage: true });
    check('no page errors along the way', problems.length === 0, problems.join('\n    '));
    await context.close();
  }

  await browser.close();

  console.log(failures === 0
    ? '\nA treasurer can open the page and record money. ✓'
    : `\n${failures} check(s) failed.`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
