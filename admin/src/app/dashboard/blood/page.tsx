'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Droplet, Users, MapPin, HeartPulse, Activity, Bell } from 'lucide-react';
import toast from 'react-hot-toast';

const GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const URGENCY_COLOR: Record<string, string> = {
  CRITICAL: 'bg-red-600',
  URGENT: 'bg-orange-500',
  ROUTINE: 'bg-gray-500',
};

export default function BloodPage() {
  const [stats, setStats] = useState<any>(null);
  const [requests, setRequests] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<'OPEN' | 'FULFILLED' | 'ALL'>('OPEN');

  async function load() {
    setLoading(true);
    try {
      const [s, r] = await Promise.all([api.bloodStats(), api.listBloodRequests(tab)]);
      setStats(s);
      setRequests(Array.isArray(r) ? r : []);
    } catch (e: any) {
      toast.error(e.message ?? 'Failed to load blood analytics');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  const d = stats?.donors ?? {};
  const rq = stats?.requests ?? {};
  const rs = stats?.responses ?? {};

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center gap-3 mb-6">
        <Droplet className="text-red-600" />
        <h1 className="text-2xl font-bold text-gray-900">Blood Donation</h1>
      </div>

      {loading && !stats ? (
        <p className="text-gray-500">Loading…</p>
      ) : (
        <>
          {/* KPI cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <Kpi icon={Users} label="Donors" value={d.total ?? 0}
              sub={`${d.fyc ?? 0} app · ${d.imported ?? 0} F2S`} color="text-blue-600" />
            <Kpi icon={MapPin} label="Location-enabled" value={d.with_location ?? 0}
              sub={`${d.available ?? 0} available · ${d.eligible ?? 0} eligible`} color="text-emerald-600" />
            <Kpi icon={Bell} label="Requests" value={rq.total ?? 0}
              sub={`${rq.open ?? 0} open · ${rq.fulfilled ?? 0} fulfilled`} color="text-orange-600" />
            <Kpi icon={HeartPulse} label="Lives helped" value={stats?.lives_helped ?? 0}
              sub={`${rs.response_rate_pct ?? 0}% response rate`} color="text-red-600" />
          </div>

          {/* Response summary */}
          <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5 mb-6">
            <div className="flex items-center gap-2 mb-3">
              <Activity className="w-4 h-4 text-gray-500" />
              <h2 className="font-semibold text-gray-800">Emergency response</h2>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
              <Stat label="Donors notified" value={rq.notified_total ?? 0} />
              <Stat label="Accepted" value={rs.accepted ?? 0} />
              <Stat label="Donations recorded" value={rs.donated ?? 0} />
              <Stat label="Response rate" value={`${rs.response_rate_pct ?? 0}%`} />
            </div>
          </div>

          {/* Blood-group coverage */}
          <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5 mb-6">
            <h2 className="font-semibold text-gray-800 mb-3">Available donors by group</h2>
            <div className="grid grid-cols-4 md:grid-cols-8 gap-3">
              {GROUPS.map((g) => {
                const n = d.coverage?.[g] ?? 0;
                return (
                  <div key={g}
                    className={`rounded-lg p-3 text-center border ${n === 0 ? 'border-red-200 bg-red-50' : 'border-gray-100 bg-gray-50'}`}>
                    <div className="font-extrabold text-gray-900">{g}</div>
                    <div className={`text-sm font-bold ${n === 0 ? 'text-red-600' : 'text-emerald-600'}`}>{n}</div>
                  </div>
                );
              })}
            </div>
            <p className="text-xs text-gray-400 mt-2">Groups showing 0 have no available donors — worth a recruitment drive.</p>
          </div>

          {/* Requests list */}
          <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-semibold text-gray-800">Requests</h2>
              <div className="flex gap-2">
                {(['OPEN', 'FULFILLED', 'ALL'] as const).map((t) => (
                  <button key={t} onClick={() => setTab(t)}
                    className={`px-3 py-1.5 rounded-full text-xs font-bold ${tab === t ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-600'}`}>
                    {t}
                  </button>
                ))}
              </div>
            </div>
            {requests.length === 0 ? (
              <p className="text-gray-400 text-sm py-6 text-center">No requests.</p>
            ) : (
              <div className="divide-y divide-gray-100">
                {requests.map((r) => (
                  <div key={r.id} className="py-3 flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-red-100 text-red-700 font-extrabold flex items-center justify-center text-sm">
                      {r.patient_blood_group}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-gray-900 text-sm flex items-center gap-2">
                        {r.units_needed} unit(s)
                        <span className={`text-white text-[10px] px-2 py-0.5 rounded-full ${URGENCY_COLOR[r.urgency] ?? 'bg-gray-500'}`}>{r.urgency}</span>
                      </div>
                      <div className="text-xs text-gray-500 truncate">
                        {r.hospital_name || '—'} · {r.requester_name || 'Unknown'}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-bold text-emerald-700">{r.accepted_count} responding</div>
                      <div className="text-xs text-gray-400">{r.notified_count} notified</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

function Kpi({ icon: Icon, label, value, sub, color }: any) {
  return (
    <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
      <div className="flex items-center gap-2 mb-2">
        <Icon className={`w-4 h-4 ${color}`} />
        <span className="text-xs font-semibold text-gray-500">{label}</span>
      </div>
      <div className="text-2xl font-extrabold text-gray-900">{value}</div>
      {sub && <div className="text-[11px] text-gray-400 mt-1">{sub}</div>}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div>
      <div className="text-xl font-extrabold text-gray-900">{value}</div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}
