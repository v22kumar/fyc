'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Issue, IssueStatus, Member } from '@/types';
import StatusBadge from '@/components/StatusBadge';
import IssueDetailDrawer from '@/components/IssueDetailDrawer';
import { CATEGORY_LABELS } from '@/types';
import { CheckCircle2 } from 'lucide-react';

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
              {[1, 2, 3, 4, 5].map((i) => (
                <tr key={i} className="animate-pulse">
                  <td className="px-5 py-4"><div className="h-4 bg-gray-200 rounded w-16"></div></td>
                  <td className="px-5 py-4"><div className="h-4 bg-gray-200 rounded w-24"></div></td>
                  <td className="px-5 py-4"><div className="h-4 bg-gray-100 rounded w-48"></div></td>
                  <td className="px-5 py-4"><div className="h-6 bg-gray-200 rounded-full w-20"></div></td>
                  <td className="px-5 py-4"><div className="h-4 bg-gray-100 rounded w-20"></div></td>
                  <td className="px-5 py-4"><div className="h-4 bg-gray-200 rounded w-12"></div></td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : issues.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 px-4 text-center">
            <div className="w-16 h-16 bg-green-50 rounded-full flex items-center justify-center mb-4">
              <CheckCircle2 className="w-8 h-8 text-green-500" />
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-1">Inbox Zero</h3>
            <p className="text-sm text-gray-500 max-w-sm">There are no issues in this state. Great job keeping the community running smoothly!</p>
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
