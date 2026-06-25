'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Tournament, Team, Fixture, ChallengeMatch } from '@/types';

const SPORT_ICONS: Record<string, string> = {
  cricket: '🏏', kabaddi: '🤼', volleyball: '🏐',
  football: '⚽', carrom: '🎯', chess: '♟️', other: '🏆',
};

export default function SportsPage() {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [challenges, setChallenges] = useState<ChallengeMatch[]>([]);
  const [selectedTournament, setSelectedTournament] = useState<Tournament | null>(null);
  const [teams, setTeams] = useState<Team[]>([]);
  const [fixtures, setFixtures] = useState<Fixture[]>([]);
  const [tab, setTab] = useState<'tournaments' | 'challenges'>('tournaments');
  const [showCreate, setShowCreate] = useState(false);

  // Create tournament form
  const [form, setForm] = useState({ name_en: '', name_ta: '', sport: 'cricket', year: new Date().getFullYear(), format: 'LEAGUE', description_en: '' });

  // Add team form
  const [teamForm, setTeamForm] = useState({ name: '', captain_name: '', contact_phone: '', is_fyc_team: false });

  // Result form
  const [resultFixture, setResultFixture] = useState<Fixture | null>(null);
  const [resultForm, setResultForm] = useState({ team_a_score: '', team_b_score: '', winner_id: '', result_notes: '' });

  async function loadTournaments() {
    const data = await api.listTournaments();
    setTournaments(data);
  }

  async function loadChallenges() {
    const data = await api.listChallenges();
    setChallenges(data);
  }

  useEffect(() => { loadTournaments(); loadChallenges(); }, []);

  async function selectTournament(t: Tournament) {
    setSelectedTournament(t);
    const [teamsData, fixturesData] = await Promise.all([
      api.listTeams(t.id),
      api.listFixtures(t.id),
    ]);
    setTeams(teamsData);
    setFixtures(fixturesData);
  }

  async function createTournament() {
    const t = await api.createTournament(form);
    setTournaments(prev => [t, ...prev]);
    setShowCreate(false);
    setForm({ name_en: '', name_ta: '', sport: 'cricket', year: new Date().getFullYear(), format: 'LEAGUE', description_en: '' });
  }

  async function addTeam() {
    if (!selectedTournament) return;
    const t = await api.createTeam(selectedTournament.id, teamForm);
    setTeams(prev => [...prev, t]);
    setTeamForm({ name: '', captain_name: '', contact_phone: '', is_fyc_team: false });
  }

  async function deleteTeam(teamId: string) {
    if (!selectedTournament) return;
    if (!confirm('Are you sure you want to remove this team?')) return;
    try {
      await api.deleteTeam(selectedTournament.id, teamId);
      setTeams(prev => prev.filter(t => t.id !== teamId));
    } catch (err: any) {
      alert(err.message || 'Failed to delete team');
    }
  }

  async function approveTeam(teamId: string) {
    if (!selectedTournament) return;
    try {
      const updated = await api.updateTeamStatus(selectedTournament.id, teamId, 'APPROVED');
      setTeams(prev => prev.map(t => t.id === teamId ? updated : t));
    } catch (err: any) {
      alert(err.message || 'Failed to approve team');
    }
  }

  async function submitResult() {
    if (!selectedTournament || !resultFixture) return;
    const updated = await api.submitFixtureResult(selectedTournament.id, resultFixture.id, resultForm);
    setFixtures(prev => prev.map(f => f.id === updated.id ? updated : f));
    setResultFixture(null);
  }

  async function respondChallenge(id: string, status: string) {
    await api.respondChallenge(id, { status, admin_response: status === 'ACCEPTED' ? 'Challenge accepted! We will contact you.' : 'Challenge declined.' });
    loadChallenges();
  }

  async function generateFixtures() {
    if (!selectedTournament) return;
    if (!confirm('Are you sure you want to generate round-robin fixtures?')) return;
    try {
      const generated = await api.generateFixtures(selectedTournament.id);
      setFixtures(generated);
    } catch (err: any) {
      alert(err.message || 'Failed to generate fixtures');
    }
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Tab header */}
      <div className="flex items-center gap-4 mb-6">
        <h1 className="text-2xl font-bold text-gray-900 mr-4">Sports Hub</h1>
        <button onClick={() => setTab('tournaments')} className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-colors ${tab === 'tournaments' ? 'bg-primary text-white' : 'text-gray-600 hover:bg-gray-100'}`}>Tournaments</button>
        <button onClick={() => setTab('challenges')} className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-colors ${tab === 'challenges' ? 'bg-primary text-white' : 'text-gray-600 hover:bg-gray-100'}`}>
          Challenges {challenges.filter(c => c.status === 'OPEN').length > 0 && <span className="ml-1 bg-red-500 text-white text-xs rounded-full px-1.5">{challenges.filter(c => c.status === 'OPEN').length}</span>}
        </button>
      </div>

      {tab === 'tournaments' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left: tournament list */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <h2 className="font-semibold text-gray-700">Tournaments</h2>
              <button onClick={() => setShowCreate(!showCreate)} className="text-xs bg-primary text-white px-3 py-1.5 rounded-lg hover:bg-primary/90">+ New</button>
            </div>

            {showCreate && (
              <div className="bg-white border border-gray-200 rounded-xl p-4 mb-3 space-y-2">
                <input placeholder="Name (English)" value={form.name_en} onChange={e => setForm(f => ({ ...f, name_en: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                <input placeholder="பெயர் (Tamil)" value={form.name_ta} onChange={e => setForm(f => ({ ...f, name_ta: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                <div className="grid grid-cols-2 gap-2">
                  <select value={form.sport} onChange={e => setForm(f => ({ ...f, sport: e.target.value }))} className="border border-gray-300 rounded-lg px-2 py-1.5 text-sm">
                    {['cricket','kabaddi','volleyball','football','carrom','chess','other'].map(s => <option key={s} value={s}>{s}</option>)}
                  </select>
                  <select value={form.format} onChange={e => setForm(f => ({ ...f, format: e.target.value }))} className="border border-gray-300 rounded-lg px-2 py-1.5 text-sm">
                    <option value="LEAGUE">League</option>
                    <option value="KNOCKOUT">Knockout</option>
                    <option value="GROUP_STAGE">Group Stage</option>
                  </select>
                </div>
                <input type="number" placeholder="Year" value={form.year} onChange={e => setForm(f => ({ ...f, year: +e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                <textarea placeholder="Description (Markdown supported) - Info, Rules, Prize Pool..." rows={3} value={form.description_en} onChange={e => setForm(f => ({ ...f, description_en: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm"></textarea>
                <button onClick={createTournament} className="w-full bg-primary text-white rounded-lg py-1.5 text-sm font-medium">Create</button>
              </div>
            )}

            <div className="space-y-2">
              {tournaments.map(t => (
                <button key={t.id} onClick={() => selectTournament(t)} className={`w-full text-left p-3 rounded-xl border transition-colors ${selectedTournament?.id === t.id ? 'border-primary bg-primary/5' : 'border-gray-200 bg-white hover:border-gray-300'}`}>
                  <div className="flex items-center gap-2">
                    <span className="text-xl">{SPORT_ICONS[t.sport] ?? '🏆'}</span>
                    <div>
                      <div className="font-medium text-sm text-gray-900">{t.name_en}</div>
                      <div className="text-xs text-gray-500">{t.sport} · {t.year} · {t.format}</div>
                    </div>
                  </div>
                  <span className={`mt-1 inline-block text-xs px-2 py-0.5 rounded-full ${t.status === 'ONGOING' ? 'bg-green-100 text-green-700' : t.status === 'COMPLETED' ? 'bg-gray-100 text-gray-500' : 'bg-blue-100 text-blue-700'}`}>{t.status}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Right: tournament detail */}
          {selectedTournament ? (
            <div className="lg:col-span-2 space-y-5">
              {/* Teams */}
              <div className="bg-white rounded-xl border border-gray-200 p-4">
                <h3 className="font-semibold text-gray-800 mb-3">Teams — Standings</h3>
                <div className="space-y-2 mb-4">
                  {teams.length === 0 ? <p className="text-sm text-gray-400">No teams yet.</p> : (
                    <table className="w-full text-sm">
                      <thead><tr className="text-xs text-gray-500 border-b"><th className="text-left py-1">Team</th><th>W</th><th>L</th><th>D</th><th>Pts</th></tr></thead>
                      <tbody>
                        {teams.map((t, i) => (
                          <tr key={t.id} className={`border-b border-gray-50 group ${t.status === 'PENDING' ? 'bg-amber-50/50' : ''}`}>
                            <td className="py-2 font-medium flex items-center gap-2">
                              <span>{i + 1}. {t.name}</span>
                              {t.is_fyc_team && <span className="text-xs bg-primary/10 text-primary px-1 rounded">FYC</span>}
                              {t.status === 'PENDING' && <span className="text-xs bg-amber-100 text-amber-800 px-1.5 py-0.5 rounded-full font-medium">Pending</span>}
                              
                              <div className="flex gap-1 ml-auto opacity-0 group-hover:opacity-100 transition-opacity">
                                {t.status === 'PENDING' && (
                                  <button onClick={() => approveTeam(t.id)} className="text-green-600 hover:bg-green-100 px-1.5 py-0.5 rounded text-xs font-medium" title="Approve">✓ Approve</button>
                                )}
                                <button onClick={() => deleteTeam(t.id)} className="text-red-500 hover:bg-red-50 px-1.5 py-0.5 rounded text-xs" title="Remove Team">✕</button>
                              </div>
                            </td>
                            <td className="text-center text-green-600">{t.wins}</td>
                            <td className="text-center text-red-500">{t.losses}</td>
                            <td className="text-center text-gray-500">{t.draws}</td>
                            <td className="text-center font-bold">{t.points}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
                <div className="border-t border-gray-100 pt-3">
                  <p className="text-xs font-medium text-gray-600 mb-2">Add Team</p>
                  <div className="grid grid-cols-2 gap-2 mb-2">
                    <input placeholder="Team name" value={teamForm.name} onChange={e => setTeamForm(f => ({ ...f, name: e.target.value }))} className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                    <input placeholder="Captain name" value={teamForm.captain_name} onChange={e => setTeamForm(f => ({ ...f, captain_name: e.target.value }))} className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                    <input placeholder="Contact phone" value={teamForm.contact_phone} onChange={e => setTeamForm(f => ({ ...f, contact_phone: e.target.value }))} className="border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                    <label className="flex items-center gap-2 text-sm text-gray-600">
                      <input type="checkbox" checked={teamForm.is_fyc_team} onChange={e => setTeamForm(f => ({ ...f, is_fyc_team: e.target.checked }))} /> FYC Team
                    </label>
                  </div>
                  <button onClick={addTeam} className="bg-primary text-white px-4 py-1.5 rounded-lg text-sm font-medium">Add Team</button>
                </div>
              </div>

              {/* Fixtures */}
              <div className="bg-white rounded-xl border border-gray-200 p-4">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-semibold text-gray-800">Fixtures</h3>
                  {fixtures.length === 0 && teams.length > 1 && (
                    <button onClick={generateFixtures} className="text-xs bg-indigo-600 text-white px-3 py-1.5 rounded-lg hover:bg-indigo-700 font-medium">Generate Fixtures</button>
                  )}
                </div>
                {fixtures.length === 0 ? <p className="text-sm text-gray-400">No fixtures scheduled.</p> : (
                  <div className="space-y-2">
                    {fixtures.map(f => (
                      <div key={f.id} className="border border-gray-100 rounded-lg p-3 text-sm">
                        <div className="flex items-center justify-between">
                          <div className="font-medium">
                            {f.team_a_name} vs {f.team_b_name}
                            {f.match_number && <span className="text-xs text-gray-400 ml-2">Match #{f.match_number}</span>}
                          </div>
                          <span className={`text-xs px-2 py-0.5 rounded-full ${f.status === 'COMPLETED' ? 'bg-green-100 text-green-700' : f.status === 'LIVE' ? 'bg-red-100 text-red-600 animate-pulse' : 'bg-blue-100 text-blue-700'}`}>{f.status}</span>
                        </div>
                        {f.scheduled_at && <div className="text-xs text-gray-400 mt-1">📅 {new Date(f.scheduled_at).toLocaleString()}</div>}
                        {f.venue && <div className="text-xs text-gray-400">📍 {f.venue}</div>}
                        {f.status === 'COMPLETED' && (
                          <div className="mt-1 text-xs font-medium text-gray-700">
                            Score: {f.team_a_score ?? '—'} vs {f.team_b_score ?? '—'}
                            {f.result_notes && <span className="ml-2 text-gray-500">({f.result_notes})</span>}
                          </div>
                        )}
                        {f.status !== 'COMPLETED' && (
                          <button onClick={() => { setResultFixture(f); setResultForm({ team_a_score: '', team_b_score: '', winner_id: '', result_notes: '' }); }} className="mt-2 text-xs text-primary underline">Enter Result</button>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="lg:col-span-2 flex items-center justify-center text-gray-400 text-sm">Select a tournament to manage</div>
          )}
        </div>
      )}

      {tab === 'challenges' && (
        <div className="space-y-3">
          {challenges.length === 0 ? <p className="text-gray-400 text-sm">No challenges yet.</p> : challenges.map(c => (
            <div key={c.id} className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-start justify-between">
                <div>
                  <div className="font-semibold text-gray-900">{c.challenger_team_name}</div>
                  <div className="text-sm text-gray-500">Captain: {c.challenger_captain} · {c.challenger_phone}</div>
                  <div className="text-sm text-gray-500">{SPORT_ICONS[c.sport]} {c.sport} {c.proposed_date && `· ${new Date(c.proposed_date).toLocaleDateString()}`} {c.venue && `· ${c.venue}`}</div>
                  {c.message && <div className="text-sm text-gray-600 mt-1 italic">"{c.message}"</div>}
                </div>
                <span className={`text-xs px-2 py-1 rounded-full font-medium ${c.status === 'OPEN' ? 'bg-yellow-100 text-yellow-700' : c.status === 'ACCEPTED' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>{c.status}</span>
              </div>
              {c.status === 'OPEN' && (
                <div className="flex gap-2 mt-3 pt-3 border-t border-gray-100">
                  <button onClick={() => respondChallenge(c.id, 'ACCEPTED')} className="flex-1 bg-green-50 text-green-700 text-sm py-1.5 rounded-lg font-medium hover:bg-green-100">Accept</button>
                  <button onClick={() => respondChallenge(c.id, 'REJECTED')} className="flex-1 bg-red-50 text-red-600 text-sm py-1.5 rounded-lg font-medium hover:bg-red-100">Decline</button>
                </div>
              )}
              {c.admin_response && <div className="mt-2 text-xs text-gray-500">Response: {c.admin_response}</div>}
            </div>
          ))}
        </div>
      )}

      {/* Result modal */}
      {resultFixture && selectedTournament && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
            <h3 className="text-lg font-bold mb-4">Enter Result — {resultFixture.team_a_name} vs {resultFixture.team_b_name}</h3>
            <div className="space-y-3">
              <input placeholder={`${resultFixture.team_a_name} score (e.g. 145/8)`} value={resultForm.team_a_score} onChange={e => setResultForm(f => ({ ...f, team_a_score: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm" />
              <input placeholder={`${resultFixture.team_b_name} score`} value={resultForm.team_b_score} onChange={e => setResultForm(f => ({ ...f, team_b_score: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm" />
              <select value={resultForm.winner_id} onChange={e => setResultForm(f => ({ ...f, winner_id: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm">
                <option value="">Select winner</option>
                <option value={resultFixture.team_a_id}>{resultFixture.team_a_name}</option>
                <option value={resultFixture.team_b_id}>{resultFixture.team_b_name}</option>
              </select>
              <input placeholder="Notes (e.g. won by 5 wickets)" value={resultForm.result_notes} onChange={e => setResultForm(f => ({ ...f, result_notes: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm" />
            </div>
            <div className="flex gap-3 mt-4">
              <button onClick={submitResult} className="flex-1 bg-primary text-white py-2 rounded-xl font-semibold">Save Result</button>
              <button onClick={() => setResultFixture(null)} className="flex-1 border border-gray-300 py-2 rounded-xl text-gray-600">Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
