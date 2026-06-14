'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Member, MembershipCard } from '@/types';

// ── helpers ──────────────────────────────────────────────────────────────────

function oneYearFromNow(): string {
  const d = new Date();
  d.setFullYear(d.getFullYear() + 1);
  return d.toISOString().slice(0, 10);
}

const STATUS_STYLES: Record<string, string> = {
  ACTIVE:   'bg-green-100  text-green-700',
  EXPIRED:  'bg-yellow-100 text-yellow-700',
  REVOKED:  'bg-red-100    text-red-700',
};

// ── Generate Card Modal ───────────────────────────────────────────────────────

interface GenerateModalProps {
  member: Member;
  onClose: () => void;
  onSuccess: (card: MembershipCard) => void;
}

function GenerateModal({ member, onClose, onSuccess }: GenerateModalProps) {
  const [designationTa, setDesignationTa] = useState('உறுப்பினர்');
  const [designationEn, setDesignationEn] = useState('Member');
  const [expiresAt, setExpiresAt] = useState(oneYearFromNow());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const card = await api.generateMembershipCard(
        member.id,
        designationTa,
        designationEn,
        expiresAt,
      );
      onSuccess(card);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate card');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="bg-white rounded-card shadow-2xl max-w-md w-full p-6">
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg font-bold text-gray-900">Generate Membership Card</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-xl leading-none"
          >
            ×
          </button>
        </div>

        {/* Member preview */}
        <div className="bg-gray-50 rounded-lg px-4 py-3 mb-5">
          <p className="text-sm font-semibold text-gray-800">{member.full_name_en ?? '—'}</p>
          {member.full_name_ta && (
            <p className="text-xs text-gray-500 mt-0.5">{member.full_name_ta}</p>
          )}
          <p className="text-xs text-gray-400 font-mono mt-1">{member.phone_number}</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-gray-600 mb-1">
              Designation (Tamil)
            </label>
            <input
              type="text"
              value={designationTa}
              onChange={(e) => setDesignationTa(e.target.value)}
              required
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-800 focus:outline-none focus:border-primary-700 focus:ring-1 focus:ring-primary-700"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-600 mb-1">
              Designation (English)
            </label>
            <input
              type="text"
              value={designationEn}
              onChange={(e) => setDesignationEn(e.target.value)}
              required
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-800 focus:outline-none focus:border-primary-700 focus:ring-1 focus:ring-primary-700"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-600 mb-1">
              Expires At
            </label>
            <input
              type="date"
              value={expiresAt}
              onChange={(e) => setExpiresAt(e.target.value)}
              required
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-800 focus:outline-none focus:border-primary-700 focus:ring-1 focus:ring-primary-700"
            />
          </div>

          {error && (
            <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
              {error}
            </p>
          )}

          <div className="flex gap-3 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 border border-gray-200 text-gray-700 rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 py-2.5 bg-[#064e3b] text-white rounded-lg text-sm font-semibold hover:bg-[#065f46] transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {loading ? 'Generating…' : 'Generate Card'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function MembershipPage() {
  const [members, setMembers] = useState<Member[]>([]);
  const [cards, setCards] = useState<MembershipCard[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalMember, setModalMember] = useState<Member | null>(null);

  useEffect(() => {
    Promise.all([api.listMembers(), api.listMembershipCards()])
      .then(([m, c]) => {
        setMembers(m);
        setCards(c);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const cardsByUserId = new Map(cards.map((c) => [c.user_id, c]));

  // Members that do not yet have a card
  const membersWithoutCards = members.filter(
    (m) =>
      (m.role === 'CLUB_MEMBER' ||
        m.role === 'EXECUTIVE_MEMBER' ||
        m.role === 'ADMIN' ||
        m.role === 'SUPER_ADMIN') &&
      !cardsByUserId.has(m.id),
  );

  // Map cards to their member for display
  const issuedCards = cards.map((card) => ({
    card,
    member: members.find((m) => m.id === card.user_id) ?? null,
  }));

  function handleCardGenerated(card: MembershipCard) {
    setCards((prev) => [card, ...prev]);
    setModalMember(null);
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-40">
        <div className="w-8 h-8 border-4 border-[#064e3b] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <>
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Digital Membership Cards</h1>
        <p className="text-sm text-gray-500 mt-1">
          {cards.length} card{cards.length !== 1 ? 's' : ''} issued · {membersWithoutCards.length} member{membersWithoutCards.length !== 1 ? 's' : ''} without a card
        </p>
      </div>

      {/* ── Section 1: Members Without Cards ─────────────────────────────── */}
      <section className="mb-10">
        <h2 className="text-base font-semibold text-gray-700 mb-3 flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-[#991b1b] inline-block" />
          Members Without Cards
          <span className="ml-auto text-xs font-normal text-gray-400">
            {membersWithoutCards.length} pending
          </span>
        </h2>

        <div className="bg-white rounded-card shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
              <tr>
                <th className="text-left px-5 py-3">Name</th>
                <th className="text-left px-5 py-3">Phone</th>
                <th className="text-left px-5 py-3">Role</th>
                <th className="text-right px-5 py-3">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {membersWithoutCards.map((m) => (
                <tr key={m.id} className="hover:bg-gray-50">
                  <td className="px-5 py-3">
                    <div className="font-medium text-gray-800">{m.full_name_en ?? '—'}</div>
                    {m.full_name_ta && (
                      <div className="text-xs text-gray-400">{m.full_name_ta}</div>
                    )}
                  </td>
                  <td className="px-5 py-3 text-gray-600 font-mono text-xs">{m.phone_number}</td>
                  <td className="px-5 py-3 text-gray-500 text-xs">{m.role}</td>
                  <td className="px-5 py-3 text-right">
                    <button
                      onClick={() => setModalMember(m)}
                      className="px-3 py-1.5 bg-[#064e3b] text-white text-xs font-semibold rounded-lg hover:bg-[#065f46] transition-colors"
                    >
                      Generate Card
                    </button>
                  </td>
                </tr>
              ))}
              {membersWithoutCards.length === 0 && (
                <tr>
                  <td colSpan={4} className="text-center text-gray-400 py-10">
                    All eligible members have cards
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      {/* ── Section 2: Issued Cards ───────────────────────────────────────── */}
      <section>
        <h2 className="text-base font-semibold text-gray-700 mb-3 flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-[#064e3b] inline-block" />
          Issued Cards
          <span className="ml-auto text-xs font-normal text-gray-400">
            {cards.length} total
          </span>
        </h2>

        <div className="bg-white rounded-card shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
              <tr>
                <th className="text-left px-5 py-3">Membership #</th>
                <th className="text-left px-5 py-3">Holder</th>
                <th className="text-left px-5 py-3">Designation</th>
                <th className="text-left px-5 py-3">Status</th>
                <th className="text-left px-5 py-3">Expires</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {issuedCards.map(({ card, member }) => (
                <tr key={card.id} className="hover:bg-gray-50">
                  <td className="px-5 py-3 font-mono text-xs font-semibold text-[#064e3b]">
                    {card.membership_number}
                  </td>
                  <td className="px-5 py-3">
                    <div className="font-medium text-gray-800">
                      {member?.full_name_en ?? '—'}
                    </div>
                    {member?.full_name_ta && (
                      <div className="text-xs text-gray-400">{member.full_name_ta}</div>
                    )}
                  </td>
                  <td className="px-5 py-3">
                    <div className="text-gray-800">{card.designation_en}</div>
                    <div className="text-xs text-gray-400">{card.designation_ta}</div>
                  </td>
                  <td className="px-5 py-3">
                    <span
                      className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${
                        STATUS_STYLES[card.status] ?? 'bg-gray-100 text-gray-600'
                      }`}
                    >
                      {card.status}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-gray-600 text-xs">
                    {new Date(card.expires_at).toLocaleDateString('en-IN', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </td>
                </tr>
              ))}
              {issuedCards.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-gray-400 py-10">
                    No cards issued yet
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      {/* Generate Card Modal */}
      {modalMember && (
        <GenerateModal
          member={modalMember}
          onClose={() => setModalMember(null)}
          onSuccess={handleCardGenerated}
        />
      )}
    </>
  );
}
