'use client';
/**
 * The queue where somebody asking to join the club is actually let in.
 *
 * The model, the endpoints and the approve/reject logic have existed since the
 * feature was first written. Nothing in this portal ever called them — so a
 * member who picked "Club Member" on the registration form created a PENDING
 * row that no screen displayed and nobody could act on. The request was made,
 * recorded, and never seen.
 *
 * Below the queue: accounts that appear more than once. Reported only. Merging
 * is not reversible and only somebody who knows these people can say which row
 * is real, so this page shows what each account holds and leaves the decision
 * where it belongs.
 */
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { ClubRequest, DuplicateGroup } from '@/types';

function whenAsked(iso: string): string {
  const then = new Date(iso).getTime();
  const days = Math.floor((Date.now() - then) / 86_400_000);
  if (days >= 1) return `waiting ${days} day${days === 1 ? '' : 's'}`;
  const hours = Math.floor((Date.now() - then) / 3_600_000);
  if (hours >= 1) return `waiting ${hours} hour${hours === 1 ? '' : 's'}`;
  return 'just now';
}

export default function ClubRequestsPage() {
  const [requests, setRequests] = useState<ClubRequest[]>([]);
  const [duplicates, setDuplicates] = useState<DuplicateGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  function load() {
    setLoading(true);
    setError(null);
    Promise.all([api.listClubRequests(), api.listDuplicateMembers()])
      .then(([reqs, dups]) => {
        setRequests(reqs);
        setDuplicates(dups);
      })
      .catch((e: any) => setError(e?.message ?? 'Could not load requests'))
      .finally(() => setLoading(false));
  }

  useEffect(load, []);

  async function decide(req: ClubRequest, approve: boolean) {
    // Naming the person in the confirmation, not just the action: approving is
    // granting somebody the run of the club's data, and "are you sure?" with no
    // name attached is a question nobody reads.
    const verb = approve ? 'Approve' : 'Reject';
    if (!confirm(`${verb} ${req.full_name_en}${req.phone_number ? ` (${req.phone_number})` : ''}?`)) return;

    setBusyId(req.id);
    try {
      if (approve) await api.approveClubRequest(req.id);
      else await api.rejectClubRequest(req.id);
      setRequests((prev) => prev.filter((r) => r.id !== req.id));
    } catch (e: any) {
      alert(e?.message ?? `Could not ${verb.toLowerCase()} the request`);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Club membership</h1>
        <p className="mt-1 text-sm text-gray-500">
          People asking to be recognised as club members. Approving grants the
          CLUB_MEMBER role; rejecting leaves them as they are and can be asked again.
        </p>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
          {error}
          <button onClick={load} className="ml-3 font-medium underline">Try again</button>
        </div>
      )}

      {loading ? (
        <div className="h-24 animate-pulse rounded-lg bg-gray-100" />
      ) : requests.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center text-sm text-gray-500">
          No requests waiting.
        </div>
      ) : (
        <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">Name</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">Phone</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">Asked</th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">Decision</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {requests.map((r) => (
                <tr key={r.id}>
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-900">{r.full_name_en}</div>
                    <div className="text-xs text-gray-500">{r.full_name_ta}</div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700">{r.phone_number ?? '—'}</td>
                  <td className="px-4 py-3 text-sm text-gray-500">{whenAsked(r.requested_at)}</td>
                  <td className="px-4 py-3 text-right">
                    <button
                      disabled={busyId === r.id}
                      onClick={() => decide(r, true)}
                      className="rounded-md bg-green-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
                    >
                      Approve
                    </button>
                    <button
                      disabled={busyId === r.id}
                      onClick={() => decide(r, false)}
                      className="ml-2 rounded-md border border-gray-300 px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                    >
                      Reject
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {duplicates.length > 0 && (
        <div>
          <h2 className="text-lg font-semibold text-gray-900">
            Accounts that look like the same person
          </h2>
          <p className="mt-1 text-sm text-gray-500">
            Reported, not merged — merging cannot be undone, and only somebody who
            knows these people can say which account is the real one.
          </p>
          <div className="mt-4 space-y-4">
            {duplicates.map((g) => (
              <div key={g.key} className="overflow-hidden rounded-lg border border-amber-200 bg-amber-50">
                <div className="border-b border-amber-200 px-4 py-2 text-sm font-medium text-amber-900">
                  {g.accounts[0]?.full_name_en} · {g.accounts.length} accounts
                </div>
                <table className="min-w-full text-sm">
                  <tbody className="divide-y divide-amber-200">
                    {g.accounts.map((a) => (
                      <tr key={a.user_id}>
                        <td className="px-4 py-2 text-gray-700">{a.phone_number ?? '— no phone —'}</td>
                        <td className="px-4 py-2 text-gray-700">{a.email ?? '— no email —'}</td>
                        <td className="px-4 py-2 text-gray-500">{a.role}</td>
                        <td className="px-4 py-2 text-gray-500">
                          {a.is_verified ? 'verified' : 'unverified'}
                        </td>
                        <td className="px-4 py-2 text-xs text-gray-400">
                          {a.created_at ? new Date(a.created_at).toLocaleDateString() : ''}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
