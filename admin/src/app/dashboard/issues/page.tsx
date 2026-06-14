'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Issue, IssueStatus, Member } from '@/types';
import StatusBadge from '@/components/StatusBadge';
import IssueDetailDrawer from '@/components/IssueDetailDrawer';
import { CATEGORY_LABELS } from '@/types';

const TABS: { label: string; value: IssueStatus | 'ALL' }[] = [
  { label: 'All',          value: 'ALL' },
  { label: 'New',          value: 'NEW' },
  { label: 'Assigned',     value: 'ASSIGNED' },
  { label: 'Under Review', value: 'UNDER_REVIEW' },
  { label: 'Escalated',   value: 'ESCALATED' },
  { label: 'Resolved',    value: 'RESOLVED' },
  { label: 'Closed',      value: 'CLOSED' },
];

export default function IssuesPage() {
  const [issues, setIssues] = useState<Issue[]>([]);
  const [volunteers, setVolunteers] = useState<Member[]>([]);
  const [tab, setTab] = useState<IssueStatus | 'ALL'>('ALL');
  const [selected, setSelected] = useState<Issue | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try {
      const [iss, vols] = await Promise.all([
        api.listIssues(tab === 'ALL' ? undefined : tab),
        api.listMembers('VOLUNTEER'),
      ]);
      setIssues(iss);
      setVolunteers(vols);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, [tab]);

  function handleUpdated(updated: Issue) {
    setIssues((prev) => prev.map((i) => (i.id === updated.id ? updated : i)));
    setSelected(updated);
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Issue Triage</h1>
        <p className="text-sm text-gray-500 mt-1">
          Review, assign, and move issues through the workflow
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-white rounded-card border border-gray-100 p-1 shadow-sm w-fit">
        {TABS.map((t) => (
          <button
            key={t.value}
            onClick={() => setTab(t.value)}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
              tab === t.value
                ? 'bg-primary-900 text-white shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="bg-white rounded-card shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-40">
            <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : issues.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <div className="text-4xl mb-3">🎉</div>
            <p>No issues in this state</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
              <tr>
                <th className="text-left px-5 py-3">ID</th>
                <th className="text-left px-5 py-3">Category</th>
                <th className="text-left px-5 py-3">Description</th>
                <th className="text-left px-5 py-3">Status</th>
                <th className="text-left px-5 py-3">Submitted</th>
                <th className="text-left px-5 py-3">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {issues.map((issue) => (
                <tr
                  key={issue.id}
                  className="hover:bg-gray-50 cursor-pointer"
                  onClick={() => setSelected(issue)}
                >
                  <td className="px-5 py-3 font-mono text-xs text-gray-400">
                    #{issue.id.substring(0, 8)}
                  </td>
                  <td className="px-5 py-3 font-medium text-gray-800">
                    {CATEGORY_LABELS[issue.category]}
                  </td>
                  <td className="px-5 py-3 text-gray-600 max-w-xs">
                    <p className="truncate">{issue.description_en || issue.description_ta}</p>
                  </td>
                  <td className="px-5 py-3">
                    <StatusBadge status={issue.status} />
                  </td>
                  <td className="px-5 py-3 text-gray-400 text-xs">
                    {new Date(issue.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-5 py-3">
                    <button
                      onClick={(e) => { e.stopPropagation(); setSelected(issue); }}
                      className="text-xs text-primary-900 font-medium hover:underline"
                    >
                      Open →
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Detail Drawer */}
      {selected && (
        <IssueDetailDrawer
          issue={selected}
          volunteers={volunteers}
          onClose={() => setSelected(null)}
          onUpdated={handleUpdated}
        />
      )}
    </div>
  );
}
