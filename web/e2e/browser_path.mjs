/**
 * Where Chromium actually is.
 *
 * Playwright looks for a browser build numbered to match its own version. CI
 * images and dev containers pin a browser independently of the npm package, and
 * when the two disagree the error is "Please run npx playwright install" — which
 * on a machine with no network, or one that already ships a browser, is a dead
 * end that reads like a broken test.
 *
 * That is not hypothetical: it made the chess suite unrunnable in this
 * container while it passed in CI, so the one test that proves a game can be
 * played could not be run on demand three days before a tournament.
 *
 * Order matters. An explicit E2E_CHROMIUM wins, then the path used by images
 * that preinstall one, then Playwright's own resolution.
 */
import { existsSync } from 'node:fs';

export function browserPath() {
  for (const candidate of [process.env.E2E_CHROMIUM, '/opt/pw-browsers/chromium']) {
    if (candidate && existsSync(candidate)) return candidate;
  }
  return undefined;
}

/** Launch options, so a caller can spread them without caring about the above. */
export function launchOptions(extra = {}) {
  const executablePath = browserPath();
  return executablePath ? { executablePath, ...extra } : { ...extra };
}
