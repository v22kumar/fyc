'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Member } from '@/types';

const ROLE_LABELS: Record<string, string> = {
  PUBLIC_CITIZEN:   'Citizen',
  VOLUNTEER:        'Volunteer',
  CLUB_MEMBER:      'Member',
  EXECUTIVE_MEMBER: 'Executive',
  ADMIN:            'Admin',
  SUPER_ADMIN:      'Super Admin',
};

const ROLE_COLORS: Record<string, string> = {
  PUBLIC_CITIZEN:   'bg-gray-100   text-gray-600',
  VOLUNTEER:        'bg-blue-100   text-blue-700',
  CLUB_MEMBER:      'bg-green-100  text-green-700',
  EXECUTIVE_MEMBER: 'bg-yellow-100 text-yellow-700',
  ADMIN:            'bg-orange-100 text-orange-700',
  SUPER_ADMIN:      'bg-red-100    text-red-700',
};

export default function MembersPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [filter, setFilter] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listMembers().then(setMembers).catch(console.error).finally(() => setLoading(false));
  }, []);

  const shown = filter
    ? members.filter((m) => m.role === filter)
    : members;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Members</h1>
        <p className="text-sm text-gray-500 mt-1">{members.length} total users</p>
      </div>

      {/* Filter */}
      <div className="flex gap-2 mb-6 flex-wrap">
        {['', 'VOLUNTEER', 'EXECUTIVE_MEMBER', 'ADMIN', 'PUBLIC_CITIZEN'].map((role) => (
          <button
            key={role}
            onClick={() => setFilter(role)}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
              filter === role
                ? 'bg-primary-900 text-white border-primary-900'
                : 'border-gray-200 text-gray-600 hover:border-primary hover:text-primary-900'
            }`}
          >
            {role ? ROLE_LABELS[role] : 'All Roles'}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-40">
          <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="bg-white rounded-card shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
              <tr>
                <th className="text-left px-5 py-3">Name</th>
                <th className="text-left px-5 py-3">Phone</th>
                <th className="text-left px-5 py-3">Role</th>
                <th className="text-left px-5 py-3">Lang</th>
                <th className="text-left px-5 py-3">Verified</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {shown.map((m) => (
                <tr key={m.id} className="hover:bg-gray-50">
                  <td className="px-5 py-3">
                    <div className="font-medium text-gray-800">
                      {m.full_name_en ?? '—'}
                    </div>
                    {m.full_name_ta && (
                      <div className="text-xs text-gray-400">{m.full_name_ta}</div>
                    )}
                  </td>
                  <td className="px-5 py-3 text-gray-600 font-mono text-xs">{m.phone_number}</td>
                  <td className="px-5 py-3">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${ROLE_COLORS[m.role] ?? 'bg-gray-100 text-gray-600'}`}>
                      {ROLE_LABELS[m.role] ?? m.role}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-gray-500 text-xs uppercase">{m.preferred_language}</td>
                  <td className="px-5 py-3">
                    <span className={m.is_verified ? 'text-green-600' : 'text-gray-400'}>
                      {m.is_verified ? '✓' : '–'}
                    </span>
                  </td>
                </tr>
              ))}
              {shown.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-gray-400 py-10">No members found</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
