export const DEFAULT_ORG_ID =
  import.meta.env.PUBLIC_DEFAULT_ORG_ID ?? '8f8b80b7-4b71-4770-b183-5c5f49e49a1d';

// Fallback must match the real backend Fly app (also used in BaseLayout.astro).
export const API_BASE =
  import.meta.env.PUBLIC_API_BASE ?? 'https://api.fycconnect.com';

// Where the member app lives.
//
// The public site and the member app are two deliberately separate surfaces
// (see docs/architecture/where-things-live.md). Pages here that used to be a
// second implementation of a member screen redirect into the one built from
// the same source as Android, so the two can never quietly disagree about what
// signing in — or donating blood — means.
export const MEMBER_APP_BASE =
  import.meta.env.PUBLIC_MEMBER_APP_BASE ?? 'https://app.fycconnect.com';

// Whether the member app is live and proven.
//
// The redirects below are sequenced deliberately: pointing this site at
// app.fycconnect.com before that app is deployed and checked would replace a
// working page with a dead link, on the site people arrive at. So the switch
// is config, not code — set PUBLIC_MEMBER_APP_READY=true once the app answers,
// and unset it to fall straight back to the pages that are still here.
export const MEMBER_APP_READY =
  import.meta.env.PUBLIC_MEMBER_APP_READY === 'true';
