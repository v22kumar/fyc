export const DEFAULT_ORG_ID =
  import.meta.env.PUBLIC_DEFAULT_ORG_ID ?? '8f8b80b7-4b71-4770-b183-5c5f49e49a1d';

// Fallback must match the real backend Fly app (also used in BaseLayout.astro).
export const API_BASE =
  import.meta.env.PUBLIC_API_BASE ?? 'https://fyc-backend.fly.dev';
