'use client';
import { useState } from 'react';
import type { Issue, IssueStatus, Member } from '@/types';
import { VALID_TRANSITIONS, STATUS_LABELS, CATEGORY_LABELS } from '@/types';
import StatusBadge from './StatusBadge';
import { api } from '@/lib/api';
import toast from 'react-hot-toast';
import { Loader2 } from 'lucide-react';

interface Props {
  issue: Issue;
  volunteers: Member[];
  onClose: () => void;
  onUpdated: (updated: Issue) => void;
}

export default function IssueDetailDrawer({ issue, volunteers, onClose, onUpdated }: Props) {
  const [assignee, setAssignee] = useState(issue.assigned_volunteer_id ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const transitions = VALID_TRANSITIONS[issue.status];

  async function doTransition(newStatus: IssueStatus) {
    setError('');
    setSaving(true);
    try {
      const updated = await api.updateIssueStatus(
        issue.id,
        newStatus,
        newStatus === 'ASSIGNED' && assignee ? assignee : undefined,
      );
      toast.success(`Issue moved to ${STATUS_LABELS[newStatus]}`);
      onUpdated(updated);
    } catch (e: unknown) {
      const errorMsg = e instanceof Error ? e.message : 'Update failed';
      toast.error(errorMsg);
      setError(errorMsg);
    } finally {
      setSaving(false);
    }
  }

  const mapsUrl = `https://www.google.com/maps?q=${issue.latitude},${issue.longitude}`;

  return (
    <div className="fixed inset-0 z-50 flex">
      {/* Backdrop */}
      <div className="flex-1 bg-black/40" onClick={onClose} />

      {/* Drawer */}
      <div className="w-full max-w-lg bg-white shadow-2xl flex flex-col overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b">
          <div>
            <h2 className="font-bold text-lg text-gray-900">
              {CATEGORY_LABELS[issue.category]}
            </h2>
            <p className="text-xs text-gray-400 mt-0.5">
              #{issue.id.substring(0, 8)} &middot; {new Date(issue.created_at).toLocaleDateString()}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <StatusBadge status={issue.status} />
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-700 text-xl leading-none"
            >
              ✕
            </button>
          </div>
        </div>

        {/* Body */}
        <div className="p-5 space-y-5 flex-1">
          {/* Descriptions */}
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
              Description (Tamil)
            </p>
            <p className="text-sm text-gray-800 bg-gray-50 rounded-lg p-3">
              {issue.description_ta || '—'}
            </p>
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
              Description (English)
            </p>
            <p className="text-sm text-gray-800 bg-gray-50 rounded-lg p-3">
              {issue.description_en || '—'}
            </p>
          </div>

          {/* Location */}
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
              Location
            </p>
            <a
              href={mapsUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 text-sm text-primary-900 hover:underline"
            >
              📍 {issue.latitude.toFixed(5)}, {issue.longitude.toFixed(5)} → View on Maps
            </a>
          </div>

          {/* Photo */}
          {issue.photo_url && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                Issue Photo
              </p>
              <img
                src={
                  issue.photo_url.startsWith('http')
                    ? issue.photo_url
                    : `${process.env.NEXT_PUBLIC_API_BASE}${issue.photo_url}`
                }
                alt="Issue"
                className="rounded-lg max-h-48 object-cover"
              />
            </div>
          )}

          {/* Volunteer assignment */}
          {transitions.includes('ASSIGNED') && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                Assign Volunteer
              </p>
              <select
                value={assignee}
                onChange={(e) => setAssignee(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="">— Select volunteer —</option>
                {volunteers.map((v) => (
                  <option key={v.id} value={v.id}>
                    {v.full_name_en ?? v.phone_number} ({v.phone_number})
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Transition buttons */}
          {transitions.length > 0 && (
            <div>
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                Move to
              </p>
              <div className="flex flex-wrap gap-2">
                {transitions.map((s) => (
                  <button
                    key={s}
                    onClick={() => doTransition(s)}
                    disabled={saving}
                    className="px-4 py-2 bg-primary-900 text-white text-sm rounded-lg hover:bg-primary-800 disabled:opacity-70 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
                  >
                    {saving && <Loader2 className="w-4 h-4 animate-spin" />}
                    {saving ? 'Saving...' : STATUS_LABELS[s]}
                  </button>
                ))}
                <button
                  onClick={() => doTransition('REJECTED')}
                  disabled={saving || issue.status !== 'NEW'}
                  className="px-4 py-2 bg-accent text-white text-sm rounded-lg hover:bg-accent-700 disabled:hidden transition-colors flex items-center justify-center gap-2"
                >
                  Reject
                </button>
              </div>
            </div>
          )}

          {error && (
            <p className="text-sm text-accent bg-accent-100 border border-accent px-3 py-2 rounded-lg">
              {error}
            </p>
          )}

          {transitions.length === 0 && (
            <p className="text-sm text-gray-400 italic">
              This issue is in a terminal state — no further transitions available.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
