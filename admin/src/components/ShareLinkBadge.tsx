'use client';

import { useState } from 'react';
import { API_BASE } from '@/lib/api';

const WEB_BASE = process.env.NEXT_PUBLIC_WEB_BASE ?? 'https://fyc-web.fly.dev';

/**
 * Short share link + scannable QR for an event ('e') or tournament ('t'),
 * shown right where admins manage them so the link can be copied onto a notice
 * or the QR scanned/printed. Renders nothing for rows without a code yet.
 */
export function ShareLinkBadge({ kind, code }: { kind: 'e' | 't'; code?: string | null }) {
  const [copied, setCopied] = useState(false);
  if (!code) return null;

  const path = `/${kind}/${code}`;
  const url = `${WEB_BASE}${path}`;
  const qr = `${API_BASE}/api/v1/share/qr.svg?u=${encodeURIComponent(path)}`;

  return (
    <div className="mt-3 flex items-center gap-3 rounded-lg border border-green-200 bg-green-50 p-2.5">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={qr} alt="QR code" width={64} height={64} className="h-16 w-16 shrink-0 rounded bg-white p-1" />
      <div className="min-w-0">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-green-700">Share link</p>
        <div className="mt-0.5 flex items-center gap-2">
          <code className="truncate text-sm font-bold text-green-900">{url}</code>
          <button
            type="button"
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(url);
                setCopied(true);
                setTimeout(() => setCopied(false), 1500);
              } catch {
                /* clipboard blocked — the link is still selectable above */
              }
            }}
            className="shrink-0 rounded bg-green-600 px-2 py-0.5 text-xs text-white hover:bg-green-700"
          >
            {copied ? 'Copied!' : 'Copy'}
          </button>
        </div>
      </div>
    </div>
  );
}
