'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { getUser } from '@/lib/auth';
import type { Issue, Event, CommunityStats } from '@/types';
import StatusBadge from '@/components/StatusBadge';
import { Activity, ShieldCheck, Settings, Users, ClipboardCheck, TrendingUp } from 'lucide-react';

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null);
  const [issues, setIssues] = useState<Issue[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [communityStats, setCommunityStats] = useState<CommunityStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setUser(getUser());
    Promise.all([api.listIssues(), api.listEvents(), api.getCommunityStats()])
      .then(([i, e, c]) => { setIssues(i); setEvents(e); setCommunityStats(c); })
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
          {user?.role === 'SUPER_ADMIN' ? (
            /* SUPER ADMIN VIEW */
            <div className="space-y-8">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm flex items-start gap-4">
                  <div className="p-3 bg-blue-50 text-blue-600 rounded-lg"><Activity className="w-6 h-6" /></div>
                  <div>
                    <h3 className="font-semibold text-gray-900">Platform Health</h3>
                    <p className="text-sm text-gray-500 mt-1">All systems operational. API latency is normal (42ms).</p>
                    <div className="mt-3 text-xs font-medium text-blue-600 cursor-pointer hover:underline">View detailed metrics &rarr;</div>
                  </div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm flex items-start gap-4">
                  <div className="p-3 bg-purple-50 text-purple-600 rounded-lg"><ShieldCheck className="w-6 h-6" /></div>
                  <div>
                    <h3 className="font-semibold text-gray-900">Pending Approvals</h3>
                    <p className="text-sm text-gray-500 mt-1">12 new manager accounts awaiting your review.</p>
                    <div className="mt-3 text-xs font-medium text-purple-600 cursor-pointer hover:underline">Review requests &rarr;</div>
                  </div>
                </div>
                <div className="bg-white p-6 rounded-xl border border-gray-100 shadow-sm flex items-start gap-4">
                  <div className="p-3 bg-gray-50 text-gray-600 rounded-lg"><Settings className="w-6 h-6" /></div>
                  <div>
                    <h3 className="font-semibold text-gray-900">Organization Config</h3>
                    <p className="text-sm text-gray-500 mt-1">Manage global settings, integrations, and default parameters.</p>
                    <div className="mt-3 text-xs font-medium text-gray-600 cursor-pointer hover:underline">Manage settings &rarr;</div>
                  </div>
                </div>
              </div>

              {communityStats && (
                <div>
                  <h2 className="text-xl font-bold text-gray-800 mb-4">Network Impact Overview</h2>
                  <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                    <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-5 text-white shadow-lg transform hover:scale-105 transition-transform duration-200">
                      <div className="text-3xl mb-2">🫂</div>
                      <div className="text-3xl font-black">{communityStats.total_volunteers}</div>
                      <div className="text-sm font-medium mt-1 opacity-90 uppercase tracking-wide">Total Volunteers</div>
                    </div>
                    <div className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-5 text-white shadow-lg transform hover:scale-105 transition-transform duration-200">
                      <div className="text-3xl mb-2">🎉</div>
                      <div className="text-3xl font-black">{communityStats.total_events}</div>
                      <div className="text-sm font-medium mt-1 opacity-90 uppercase tracking-wide">Global Events</div>
                    </div>
                    <div className="bg-gradient-to-br from-red-500 to-red-600 rounded-xl p-5 text-white shadow-lg transform hover:scale-105 transition-transform duration-200">
                      <div className="text-3xl mb-2">🩸</div>
                      <div className="text-3xl font-black">{communityStats.total_blood_donations}</div>
                      <div className="text-sm font-medium mt-1 opacity-90 uppercase tracking-wide">Blood Donated</div>
                    </div>
                    <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-5 text-white shadow-lg transform hover:scale-105 transition-transform duration-200">
                      <div className="text-3xl mb-2">🌳</div>
                      <div className="text-3xl font-black">{communityStats.total_trees_planted}</div>
                      <div className="text-sm font-medium mt-1 opacity-90 uppercase tracking-wide">Trees Planted</div>
                    </div>
                    <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl p-5 text-white shadow-lg transform hover:scale-105 transition-transform duration-200">
                      <div className="text-3xl mb-2">✅</div>
                      <div className="text-3xl font-black">{communityStats.total_issues_solved}</div>
                      <div className="text-sm font-medium mt-1 opacity-90 uppercase tracking-wide">Issues Solved</div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          ) : (
            /* MANAGER VIEW */
            <div className="space-y-8">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-500">Pending Actions</p>
                    <p className="text-2xl font-bold text-gray-900 mt-1">{byStatus('NEW') + byStatus('ASSIGNED')}</p>
                  </div>
                  <div className="w-12 h-12 bg-red-50 text-red-600 rounded-full flex items-center justify-center">
                    <ClipboardCheck className="w-6 h-6" />
                  </div>
                </div>
                <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-500">New Registrations</p>
                    <p className="text-2xl font-bold text-gray-900 mt-1">24</p>
                  </div>
                  <div className="w-12 h-12 bg-green-50 text-green-600 rounded-full flex items-center justify-center">
                    <Users className="w-6 h-6" />
                  </div>
                </div>
                <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-500">Monthly Growth</p>
                    <p className="text-2xl font-bold text-gray-900 mt-1">+12.5%</p>
                  </div>
                  <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-full flex items-center justify-center">
                    <TrendingUp className="w-6 h-6" />
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* Recent Issues */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 flex flex-col">
                  <div className="flex items-center justify-between p-5 border-b border-gray-100">
                    <h2 className="font-semibold text-gray-800">Needs Triage</h2>
                    <Link href="/dashboard/issues" className="text-sm text-primary-600 hover:underline font-medium">
                      View all &rarr;
                    </Link>
                  </div>
                  <div className="divide-y divide-gray-50 flex-1 overflow-auto">
                    {issues.slice(0, 5).map((issue) => (
                      <div key={issue.id} className="flex items-center justify-between px-5 py-4 hover:bg-gray-50 transition-colors">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-semibold text-gray-900">{issue.category}</span>
                            <span className="text-xs text-gray-400">#{issue.id.substring(0, 6)}</span>
                          </div>
                          <p className="text-sm text-gray-500 mt-1 line-clamp-1">{issue.description_en}</p>
                        </div>
                        <StatusBadge status={issue.status} />
                      </div>
                    ))}
                    {issues.length === 0 && (
                      <p className="text-center text-gray-400 text-sm py-8">No pending issues</p>
                    )}
                  </div>
                </div>

                {/* Upcoming Events */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 flex flex-col">
                  <div className="flex items-center justify-between p-5 border-b border-gray-100">
                    <h2 className="font-semibold text-gray-800">Upcoming Events</h2>
                    <Link href="/dashboard/events" className="text-sm text-primary-600 hover:underline font-medium">
                      Manage &rarr;
                    </Link>
                  </div>
                  <div className="divide-y divide-gray-50 flex-1 overflow-auto">
                    {events.filter(e => new Date(e.event_start) > new Date()).slice(0, 5).map((e) => (
                      <div key={e.id} className="px-5 py-4 hover:bg-gray-50 transition-colors">
                        <div className="flex items-center justify-between mb-1">
                          <h3 className="font-semibold text-gray-900">{e.title_en}</h3>
                          {e.requires_registration && <span className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded font-medium">Reg Required</span>}
                        </div>
                        <p className="text-sm text-gray-500">{new Date(e.event_start).toLocaleDateString()}</p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
