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

const PROMOTABLE_ROLES = ["PUBLIC_CITIZEN", "VOLUNTEER", "CLUB_MEMBER", "EXECUTIVE_MEMBER", "ADMIN"];

export default function MembersPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [filter, setFilter] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [promotingId, setPromotingId] = useState<string | null>(null);

  useEffect(() => {
    api.listMembers().then(setMembers).catch(console.error).finally(() => setLoading(false));
  }, []);

  async function handlePromote(userId: string, newRole: string) {
    setPromotingId(userId);
    try {
      await api.promoteUser(userId, newRole);
      setMembers((prev) =>
        prev.map((m) => (m.id === userId ? { ...m, role: newRole } : m))
      );
    } catch (err: any) {
      alert(err.message ?? 'Failed to promote user');
    } finally {
      setPromotingId(null);
    }
  }

  const [showModal, setShowModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const [fullNameEn, setFullNameEn] = useState('');
  const [fullNameTa, setFullNameTa] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('PUBLIC_CITIZEN');
  const [preferredLang, setPreferredLang] = useState('en');

  async function handleAddMember(e: React.FormEvent) {
    e.preventDefault();
    if (!fullNameEn.trim() || !fullNameTa.trim()) {
      setErrorMsg('Full Name in English and Tamil are required.');
      return;
    }
    if (!phoneNumber.trim() && !email.trim()) {
      setErrorMsg('At least one of Phone Number or Email is required.');
      return;
    }

    setSubmitting(true);
    setErrorMsg('');
    try {
      const newMember = await api.createUser({
        full_name_en: fullNameEn.trim(),
        full_name_ta: fullNameTa.trim(),
        phone_number: phoneNumber.trim() || undefined,
        email: email.trim() || undefined,
        role,
        preferred_language: preferredLang,
      });
      setMembers((prev) => [newMember, ...prev]);
      setShowModal(false);

      // Reset form
      setFullNameEn('');
      setFullNameTa('');
      setPhoneNumber('');
      setEmail('');
      setRole('PUBLIC_CITIZEN');
      setPreferredLang('en');
    } catch (err: any) {
      setErrorMsg(err.message ?? 'Failed to create member');
    } finally {
      setSubmitting(false);
    }
  }

  const shown = members.filter((m) => {
    if (filter && m.role !== filter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const nameEn = (m.full_name_en || '').toLowerCase();
      const nameTa = (m.full_name_ta || '').toLowerCase();
      const phone = (m.phone_number || '').toLowerCase();
      const email = (m.email || '').toLowerCase();
      return nameEn.includes(q) || nameTa.includes(q) || phone.includes(q) || email.includes(q);
    }
    return true;
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Members</h1>
          <p className="text-sm text-gray-500 mt-1">{members.length} total users</p>
        </div>
        <button
          onClick={() => {
            setErrorMsg('');
            setShowModal(true);
          }}
          className="bg-primary-900 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary-800 transition-colors shadow-sm"
        >
          + Add Member
        </button>
      </div>

      {/* Filter and Search */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        {/* Role Filter Buttons */}
        <div className="flex gap-2 flex-wrap">
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

        {/* Text Search Box */}
        <input
          type="text"
          placeholder="Search by name, phone, or email..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full md:w-80 px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
        />
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
                <th className="text-left px-5 py-3">Actions</th>
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
                  <td className="px-5 py-3">
                    {m.role === 'SUPER_ADMIN' ? (
                      <span className="text-xs text-gray-400 italic font-medium">No Actions</span>
                    ) : (
                      <div className="flex items-center gap-2">
                        <select
                          value={m.role}
                          disabled={promotingId === m.id}
                          onChange={(e) => handlePromote(m.id, e.target.value)}
                          className="bg-white border border-gray-200 rounded-lg px-2 py-1 text-xs font-medium text-gray-700 focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary disabled:opacity-50"
                        >
                          {PROMOTABLE_ROLES.map((role) => (
                            <option key={role} value={role}>
                              Change to {ROLE_LABELS[role] || role}
                            </option>
                          ))}
                        </select>
                        {promotingId === m.id && (
                          <div className="w-3.5 h-3.5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                        )}
                      </div>
                    )}
                  </td>
                </tr>
              ))}
              {shown.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center text-gray-400 py-10">No members found</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6 shadow-xl relative animate-in fade-in zoom-in duration-200">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Add New Member</h2>
            
            {errorMsg && (
              <div className="mb-4 p-3 bg-red-50 text-red-700 text-xs rounded-lg font-medium">
                ⚠️ {errorMsg}
              </div>
            )}
            
            <form onSubmit={handleAddMember} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Full Name (English) *</label>
                <input
                  type="text"
                  required
                  value={fullNameEn}
                  onChange={e => setFullNameEn(e.target.value)}
                  placeholder="e.g. Anbarasan A"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Full Name (Tamil) *</label>
                <input
                  type="text"
                  required
                  value={fullNameTa}
                  onChange={e => setFullNameTa(e.target.value)}
                  placeholder="எ.கா. அன்பரசன் அ"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Phone Number</label>
                <input
                  type="tel"
                  value={phoneNumber}
                  onChange={e => setPhoneNumber(e.target.value)}
                  placeholder="e.g. +919876543210"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Email Address</label>
                <input
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  placeholder="e.g. user@example.com"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Role *</label>
                  <select
                    value={role}
                    onChange={e => setRole(e.target.value)}
                    className="w-full bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
                  >
                    {PROMOTABLE_ROLES.map(r => (
                      <option key={r} value={r}>
                        {ROLE_LABELS[r] || r}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Language</label>
                  <select
                    value={preferredLang}
                    onChange={e => setPreferredLang(e.target.value)}
                    className="w-full bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary"
                  >
                    <option value="en">English</option>
                    <option value="ta">Tamil</option>
                  </select>
                </div>
              </div>

              <div className="flex gap-3 justify-end pt-4">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  disabled={submitting}
                  className="px-4 py-2 border border-gray-200 rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 bg-primary-900 hover:bg-primary-800 text-white rounded-lg text-sm font-medium transition-colors disabled:opacity-50 flex items-center gap-2"
                >
                  {submitting && (
                    <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  )}
                  {submitting ? 'Adding...' : 'Add Member'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
