'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import type { Issue, Event } from '@/types';
import StatusBadge from '@/components/StatusBadge';

export default function DashboardPage() {
  const [issues, setIssues] = useState<Issue[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([api.listIssues(), api.listEvents()])
      .then(([i, e]) => { setIssues(i); setEvents(e); })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const byStatus = (s: string) => issues.filter((i) => i.status === s).length;
  const upcoming = events.filter((e) => new Date(e.event_start) > new Date()).length;

  const stats = [
    { label: 'Total Issues',  value: issues.length,    color: 'bg-blue-50   text-blue-700',   icon: '🚧' },
    { label: 'Pending Triage',value: byStatus('NEW'),   color: 'bg-yellow-50 text-yellow-700', icon: '⏳' },
    { label: 'In Progress',   value: byStatus('ASSIGNED') + byStatus('UNDER_REVIEW'), color: 'bg-orange-50 text-orange-700', icon: '🔧' },
    { label: 'Resolved',      value: byStatus('RESOLVED') + byStatus('CLOSED'), color: 'bg-green-50  text-green-700',  icon: '✅' },
    { label: 'Upcoming Events',value: upcoming,         color: 'bg-primary-50 text-primary-900', icon: '🎗️' },
  ];

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">Friends Youth Club — Nagercoil</p>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-40">
          <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          {/* Stats */}
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
            {stats.map((s) => (
              <div key={s.label} className={`rounded-card p-4 ${s.color} shadow-sm`}>
                <div className="text-2xl mb-1">{s.icon}</div>
                <div className="text-2xl font-bold">{s.value}</div>
                <div className="text-xs font-medium mt-0.5 opacity-80">{s.label}</div>
              </div>
            ))}
          </div>

          {/* Recent Issues */}
          <div className="bg-white rounded-card shadow-sm border border-gray-100">
            <div className="flex items-center justify-between p-5 border-b border-gray-100">
              <h2 className="font-semibold text-gray-800">Recent Issues</h2>
              <Link href="/dashboard/issues" className="text-sm text-primary-900 hover:underline font-medium">
                View all →
              </Link>
            </div>
            <div className="divide-y divide-gray-50">
              {issues.slice(0, 8).map((issue) => (
                <div key={issue.id} className="flex items-center justify-between px-5 py-3">
                  <div>
                    <span className="text-sm font-medium text-gray-800">{issue.category}</span>
                    <span className="text-xs text-gray-400 ml-2">
                      #{issue.id.substring(0, 8)}
                    </span>
                    <p className="text-xs text-gray-500 mt-0.5 line-clamp-1">{issue.description_en}</p>
                  </div>
                  <StatusBadge status={issue.status} />
                </div>
              ))}
              {issues.length === 0 && (
                <p className="text-center text-gray-400 text-sm py-8">No issues yet</p>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
