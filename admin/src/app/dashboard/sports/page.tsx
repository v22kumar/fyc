'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import type { Tournament, Team, Fixture, ChallengeMatch } from '@/types';
import toast from 'react-hot-toast';
import { Trophy, Users, CalendarDays, Swords } from 'lucide-react';

const SPORT_ICONS: Record<string, string> = {
  cricket: '🏏', kabaddi: '🤼', volleyball: '🏐',
  football: '⚽', carrom: '🎯', chess: '♟️', other: '🏆',
};

export default function SportsPage() {
  const router = useRouter();
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [challenges, setChallenges] = useState<ChallengeMatch[]>([]);
  const [selectedTournament, setSelectedTournament] = useState<Tournament | null>(null);
  const [teams, setTeams] = useState<Team[]>([]);
  const [fixtures, setFixtures] = useState<Fixture[]>([]);
  const [tab, setTab] = useState<'tournaments' | 'challenges'>('tournaments');
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [isAdvanced, setIsAdvanced] = useState(false);
  const [showQuickComplete, setShowQuickComplete] = useState(false);
  const [quickCompleteForm, setQuickCompleteForm] = useState({ winner_id: '', runner_up_id: '' });
  const [submitting, setSubmitting] = useState({ tournament: false, team: false, result: false, quick: false, fixtures: false });

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

  useEffect(() => { 
    setLoading(true);
    Promise.all([loadTournaments(), loadChallenges()]).finally(() => setLoading(false));
  }, []);

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
    setSubmitting(s => ({ ...s, tournament: true }));
    try {
      const t = await api.createTournament(form);
      setTournaments(prev => [t, ...prev]);
      setShowCreate(false);
      setForm({ name_en: '', name_ta: '', sport: 'cricket', year: new Date().getFullYear(), format: 'LEAGUE', description_en: '' });
      toast.success('Tournament created successfully!');
    } finally {
      setSubmitting(s => ({ ...s, tournament: false }));
    }
  }

  async function updateStatus(id: string, status: string) {
    if (['PUBLISHED', 'COMPLETED', 'ARCHIVED'].includes(status)) {
      if (!confirm(`Are you sure you want to change status to ${status}?`)) return;
    }
    await api.updateTournamentStatus(id, status);
    setTournaments(prev => prev.map(t => t.id === id ? { ...t, status } : t));
    if (selectedTournament?.id === id) {
      setSelectedTournament(prev => prev ? { ...prev, status } : prev);
    }
    toast.success(`Status updated to ${status}`);
  }

  async function deleteTournament(id: string) {
    if (!confirm('Are you sure you want to delete this tournament? This cannot be undone.')) return;
    try {
      await api.deleteTournament(id);
      setTournaments(prev => prev.filter(t => t.id !== id));
      if (selectedTournament?.id === id) setSelectedTournament(null);
      toast.success('Tournament deleted');
    } catch (e: any) {
      toast.error(e.message || 'Failed to delete tournament');
    }
  }

  async function handleQuickComplete() {
    if (!selectedTournament) return;
    if (!quickCompleteForm.winner_id) return toast.error('Please select a winner');
    setSubmitting(s => ({ ...s, quick: true }));
    try {
      const updated = await api.quickCompleteTournament(selectedTournament.id, quickCompleteForm.winner_id, quickCompleteForm.runner_up_id || undefined);
      setTournaments(prev => prev.map(t => t.id === updated.id ? updated : t));
      setSelectedTournament(updated);
      setShowQuickComplete(false);
      setQuickCompleteForm({ winner_id: '', runner_up_id: '' });
      toast.success('Tournament completed successfully!');
    } catch (err: any) {
      toast.error(err.message || 'Failed to quick complete tournament');
    } finally {
      setSubmitting(s => ({ ...s, quick: false }));
    }
  }

  async function addTeam() {
    if (!selectedTournament) return;
    setSubmitting(s => ({ ...s, team: true }));
    try {
      const t = await api.createTeam(selectedTournament.id, teamForm);
      setTeams(prev => [...prev, t]);
      setTeamForm({ name: '', captain_name: '', contact_phone: '', is_fyc_team: false });
      toast.success('Team added successfully!');
    } finally {
      setSubmitting(s => ({ ...s, team: false }));
    }
  }

  async function deleteTeam(teamId: string) {
    if (!selectedTournament) return;
    if (!confirm('Are you sure you want to remove this team?')) return;
    try {
      await api.deleteTeam(selectedTournament.id, teamId);
      setTeams(prev => prev.filter(t => t.id !== teamId));
      toast.success('Team removed');
    } catch (err: any) {
      toast.error(err.message || 'Failed to delete team');
    }
  }

  async function handleTeamStatus(teamId: string, status: 'APPROVED' | 'REJECTED') {
    if (!selectedTournament) return;
    try {
      const updated = await api.updateTeamStatus(selectedTournament.id, teamId, status);
      setTeams(prev => prev.map(t => t.id === teamId ? updated : t));
      toast.success(`Team ${status.toLowerCase()}`);
    } catch (err: any) {
      toast.error(err.message || `Failed to ${status.toLowerCase()} team`);
    }
  }

  async function submitResult() {
    if (!selectedTournament || !resultFixture) return;
    setSubmitting(s => ({ ...s, result: true }));
    try {
      const updated = await api.submitFixtureResult(selectedTournament.id, resultFixture.id, resultForm);
      setFixtures(prev => prev.map(f => f.id === updated.id ? updated : f));
      setResultFixture(null);
      toast.success('Result saved successfully');
    } finally {
      setSubmitting(s => ({ ...s, result: false }));
    }
  }

  async function respondChallenge(id: string, status: string) {
    await api.respondChallenge(id, { status, admin_response: status === 'ACCEPTED' ? 'Challenge accepted! We will contact you.' : 'Challenge declined.' });
    toast.success(`Challenge ${status.toLowerCase()}`);
    loadChallenges();
  }

  async function generateFixtures() {
    if (!selectedTournament) return;
    if (!confirm('Are you sure you want to generate round-robin fixtures?')) return;
    setSubmitting(s => ({ ...s, fixtures: true }));
    try {
      const generated = await api.generateFixtures(selectedTournament.id);
      setFixtures(generated);
      toast.success('Fixtures generated successfully');
    } catch (err: any) {
      toast.error(err.message || 'Failed to generate fixtures');
    } finally {
      setSubmitting(s => ({ ...s, fixtures: false }));
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
              <div className="bg-white border border-gray-200 rounded-xl p-4 mb-3 space-y-3">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-semibold text-gray-700">Create Tournament</span>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-medium text-gray-500 uppercase tracking-wide">Advanced</span>
                    <button
                      type="button"
                      onClick={() => setIsAdvanced(!isAdvanced)}
                      className={`relative inline-flex h-4 w-7 items-center rounded-full transition-colors ${isAdvanced ? 'bg-primary' : 'bg-gray-200'}`}
                    >
                      <span className={`inline-block h-2 w-2 transform rounded-full bg-white transition-transform ${isAdvanced ? 'translate-x-4' : 'translate-x-1'}`} />
                    </button>
                  </div>
                </div>

                <div className="space-y-2">
                  <input placeholder="Name (E.g. FYC Premier League)" value={form.name_en} onChange={e => setForm(f => ({ ...f, name_en: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                  
                  {isAdvanced && (
                    <input placeholder="பெயர் (Tamil)" value={form.name_ta} onChange={e => setForm(f => ({ ...f, name_ta: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm" />
                  )}

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
                  
                  {isAdvanced && (
                    <textarea placeholder="Description (Markdown supported) - Info, Rules, Prize Pool..." rows={3} value={form.description_en} onChange={e => setForm(f => ({ ...f, description_en: e.target.value }))} className="w-full border border-gray-300 rounded-lg px-3 py-1.5 text-sm"></textarea>
                  )}

                  <button onClick={createTournament} disabled={submitting.tournament} className="w-full bg-primary text-white rounded-lg py-1.5 text-sm font-medium disabled:opacity-70 disabled:cursor-not-allowed">
                    {submitting.tournament ? 'Creating...' : 'Create Tournament'}
                  </button>
                </div>
              </div>
            )}

            <div className="space-y-2">
              {loading ? (
                [1, 2, 3].map(i => (
                  <div key={i} className="w-full p-3 rounded-xl border border-gray-100 bg-white animate-pulse">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-6 h-6 bg-gray-200 rounded-full"></div>
                      <div className="flex-1">
                        <div className="h-4 bg-gray-200 rounded w-1/2 mb-1"></div>
                        <div className="h-3 bg-gray-100 rounded w-3/4"></div>
                      </div>
                    </div>
                    <div className="h-4 bg-gray-100 rounded-full w-16 mt-2"></div>
                  </div>
                ))
              ) : tournaments.length === 0 ? (
                <div className="flex flex-col items-center justify-center p-8 bg-gray-50 border border-dashed border-gray-200 rounded-xl text-center">
                  <Trophy className="w-8 h-8 text-gray-400 mb-2" />
                  <p className="text-sm font-medium text-gray-700">No tournaments</p>
                  <p className="text-xs text-gray-500 mt-1">Create one to get started</p>
                </div>
              ) : (
                tournaments.map(t => (
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
                ))
              )}
            </div>
          </div>

          {/* Right: tournament detail */}
          {selectedTournament ? (
            <div className="lg:col-span-2 space-y-5">
              
              {/* Tournament Header Info */}
              <div className="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
                <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                  <div>
                    <h2 className="text-xl font-bold text-gray-900">{selectedTournament.name_en}</h2>
                    <p className="text-sm text-gray-500 mt-1">{selectedTournament.sport} • {selectedTournament.year} • {selectedTournament.format}</p>
                    
                    <div className="mt-4 flex flex-wrap gap-4 text-sm">
                      {selectedTournament.registration_close_date && (
                        <div className="bg-gray-50 px-3 py-1.5 rounded-lg border border-gray-100">
                          <span className="text-gray-500 mr-2">Reg Closes:</span>
                          <span className="font-medium text-gray-900">{new Date(selectedTournament.registration_close_date).toLocaleDateString()}</span>
                        </div>
                      )}
                      
                      <div className="bg-gray-50 px-3 py-1.5 rounded-lg border border-gray-100">
                        <span className="text-gray-500 mr-2">Teams:</span>
                        <span className="font-medium text-gray-900">
                          {teams.filter(t => t.status === 'APPROVED').length} 
                          {selectedTournament.num_teams ? ` / ${selectedTournament.num_teams}` : ''}
                        </span>
                      </div>
                    </div>
                  </div>
                  
                  {/* Action Bar */}
                  <div className="flex flex-wrap gap-2 justify-end">
                    {selectedTournament.status === 'DRAFT' && (
                      <button onClick={() => updateStatus(selectedTournament.id, 'UPCOMING')} className="text-sm bg-indigo-100 text-indigo-700 px-4 py-2 rounded-lg hover:bg-indigo-200 font-medium transition-colors">Approve Draft</button>
                    )}
                    {['DRAFT', 'UPCOMING'].includes(selectedTournament.status) && (
                      <button onClick={() => updateStatus(selectedTournament.id, 'PUBLISHED')} className="text-sm bg-green-100 text-green-700 px-4 py-2 rounded-lg hover:bg-green-200 font-medium transition-colors">Publish</button>
                    )}
                    {selectedTournament.status === 'PUBLISHED' && (
                      <button onClick={() => updateStatus(selectedTournament.id, 'ONGOING')} className="text-sm bg-blue-100 text-blue-700 px-4 py-2 rounded-lg hover:bg-blue-200 font-medium transition-colors">Start Tournament</button>
                    )}
                    {selectedTournament.status === 'ONGOING' && (
                      <button onClick={() => updateStatus(selectedTournament.id, 'COMPLETED')} className="text-sm bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200 font-medium transition-colors">Mark Completed</button>
                    )}
                    
                    <div className="flex gap-2 ml-4 pl-4 border-l border-gray-200">
                      {selectedTournament.status !== 'COMPLETED' && selectedTournament.status !== 'ARCHIVED' && (
                        <button onClick={() => setShowQuickComplete(!showQuickComplete)} className="text-sm border border-purple-200 text-purple-700 px-3 py-2 rounded-lg hover:bg-purple-50 font-medium transition-colors">Quick Complete</button>
                      )}
                      <button onClick={() => deleteTournament(selectedTournament.id)} className="text-sm border border-red-200 text-red-700 px-3 py-2 rounded-lg hover:bg-red-50 font-medium transition-colors">Delete</button>
                    </div>
                  </div>
                </div>
              </div>

              {/* Quick Complete Form */}
              {showQuickComplete && (
                <div className="bg-purple-50 border border-purple-100 rounded-xl p-4 mb-4">
                  <h4 className="font-semibold text-purple-900 mb-2 text-sm">Quick Complete Tournament</h4>
                  <p className="text-xs text-purple-700 mb-3">Skip remaining fixtures and immediately declare winners.</p>
                  <div className="grid grid-cols-2 gap-3 mb-3">
                    <div>
                      <label className="block text-xs font-medium text-purple-800 mb-1">Winner *</label>
                      <select value={quickCompleteForm.winner_id} onChange={e => setQuickCompleteForm(f => ({ ...f, winner_id: e.target.value }))} className="w-full border border-purple-200 rounded-lg px-2 py-1.5 text-sm bg-white">
                        <option value="">Select Winner</option>
                        {teams.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-purple-800 mb-1">Runner Up (Optional)</label>
                      <select value={quickCompleteForm.runner_up_id} onChange={e => setQuickCompleteForm(f => ({ ...f, runner_up_id: e.target.value }))} className="w-full border border-purple-200 rounded-lg px-2 py-1.5 text-sm bg-white">
                        <option value="">Select Runner Up</option>
                        {teams.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
                      </select>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button onClick={handleQuickComplete} disabled={submitting.quick} className="text-xs bg-purple-600 text-white px-4 py-1.5 rounded-lg hover:bg-purple-700 font-medium disabled:opacity-70 disabled:cursor-not-allowed">
                      {submitting.quick ? 'Processing...' : 'Complete Tournament'}
                    </button>
                    <button onClick={() => setShowQuickComplete(false)} disabled={submitting.quick} className="text-xs bg-white text-purple-700 border border-purple-200 px-4 py-1.5 rounded-lg hover:bg-purple-50 font-medium disabled:opacity-70 disabled:cursor-not-allowed">Cancel</button>
                  </div>
                </div>
              )}

              {/* Teams */}
              <div className="bg-white rounded-xl border border-gray-200 p-4">
                <h3 className="font-semibold text-gray-800 mb-3">Teams — Standings</h3>
                <div className="space-y-2 mb-4">
                  {teams.length === 0 ? (
                    <div className="flex flex-col items-center justify-center p-8 bg-gray-50 border border-dashed border-gray-200 rounded-xl text-center">
                      <Users className="w-8 h-8 text-gray-400 mb-2" />
                      <p className="text-sm font-medium text-gray-700">No teams yet</p>
                      <p className="text-xs text-gray-500 mt-1">Add teams below to start the tournament</p>
                    </div>
                  ) : (
                    <table className="w-full text-sm">
                      <thead><tr className="text-xs text-gray-500 border-b"><th className="text-left py-1">Team</th><th>W</th><th>L</th><th>D</th><th>Pts</th></tr></thead>
                      <tbody>
                        {teams.map((t, i) => (
                          <tr key={t.id} className={`border-b border-gray-50 group ${t.status === 'PENDING' ? 'bg-amber-50/50' : ''}`}>
                            <td className="py-2 font-medium flex items-center gap-2">
                              <span>{i + 1}. {t.name}</span>
                              {t.is_fyc_team && <span className="text-xs bg-primary/10 text-primary px-1 rounded">FYC</span>}
                              {t.status === 'PENDING' && <span className="text-xs bg-yellow-100 border border-yellow-300 text-yellow-800 px-2 py-0.5 rounded-full font-bold shadow-sm flex items-center gap-1"><span className="animate-pulse">⏳</span> Pending Approval</span>}
                              
                              <div className="flex gap-2 ml-auto opacity-100 group-hover:opacity-100 transition-opacity items-center">
                                {t.status === 'PENDING' && (
                                  <>
                                    <button onClick={() => handleTeamStatus(t.id, 'APPROVED')} className="text-white bg-green-600 hover:bg-green-700 px-3 py-1 rounded-lg text-xs font-bold shadow-sm transition-colors flex items-center gap-1" title="Approve">✓ Approve</button>
                                    <button onClick={() => handleTeamStatus(t.id, 'REJECTED')} className="text-white bg-red-600 hover:bg-red-700 px-3 py-1 rounded-lg text-xs font-bold shadow-sm transition-colors flex items-center gap-1" title="Reject">✕ Reject</button>
                                  </>
                                )}}
                                <button onClick={() => deleteTeam(t.id)} className="text-red-500 hover:bg-red-50 px-1.5 py-0.5 rounded text-xs" title="Remove Team">🗑️</button>
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
                  <button onClick={addTeam} disabled={submitting.team} className="bg-primary text-white px-4 py-1.5 rounded-lg text-sm font-medium disabled:opacity-70 disabled:cursor-not-allowed">
                    {submitting.team ? 'Adding...' : 'Add Team'}
                  </button>
                </div>
              </div>

              {/* Fixtures */}
              <div className="bg-white rounded-xl border border-gray-200 p-4">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-semibold text-gray-800">Fixtures</h3>
                  {(() => {
                    const approvedTeams = teams.filter(t => t.status === 'APPROVED');
                    const hasEnoughTeams = selectedTournament.num_teams ? approvedTeams.length >= selectedTournament.num_teams : approvedTeams.length > 1;
                    const canGenerate = ['PUBLISHED', 'UPCOMING', 'DRAFT'].includes(selectedTournament.status);
                    
                    return (teams.length > 1 && canGenerate) ? (
                      <button 
                        onClick={generateFixtures} 
                        disabled={!hasEnoughTeams || submitting.fixtures}
                        className="text-xs bg-indigo-600 text-white px-3 py-1.5 rounded-lg hover:bg-indigo-700 font-medium disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors flex items-center gap-2"
                        title={!hasEnoughTeams ? `Need ${selectedTournament.num_teams || 2} approved teams` : ''}
                      >
                        {submitting.fixtures ? 'Generating...' : (fixtures.length === 0 ? 'Generate Fixtures' : 'Regenerate Fixtures')}
                      </button>
                    ) : null;
                  })()}
                </div>
                {fixtures.length === 0 ? (
                  <div className="flex flex-col items-center justify-center p-8 bg-gray-50 border border-dashed border-gray-200 rounded-xl text-center">
                    <CalendarDays className="w-8 h-8 text-gray-400 mb-2" />
                    <p className="text-sm font-medium text-gray-700">No fixtures scheduled</p>
                    <p className="text-xs text-gray-500 mt-1">Generate fixtures when teams are ready</p>
                  </div>
                ) : (
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
                          <div className="flex gap-4 mt-2">
                            <button onClick={() => { setResultFixture(f); setResultForm({ team_a_score: '', team_b_score: '', winner_id: '', result_notes: '' }); }} className="text-xs text-primary underline">Enter Result</button>
                            {selectedTournament?.sport === 'cricket' && (
                              <button onClick={() => router.push(`/dashboard/sports/cricket/${f.id}`)} className="text-xs bg-green-100 text-green-800 px-2 py-0.5 rounded-full font-bold">Score Live Match 🏏</button>
                            )}
                          </div>
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
          {loading ? (
            [1, 2, 3].map(i => (
              <div key={i} className="bg-white rounded-xl border border-gray-100 p-4 animate-pulse">
                <div className="h-5 bg-gray-200 rounded w-1/3 mb-2"></div>
                <div className="h-4 bg-gray-100 rounded w-1/2 mb-1"></div>
                <div className="h-4 bg-gray-100 rounded w-2/3 mb-3"></div>
                <div className="h-4 bg-gray-100 rounded w-full"></div>
              </div>
            ))
          ) : challenges.length === 0 ? (
            <div className="flex flex-col items-center justify-center p-12 bg-white border border-dashed border-gray-200 rounded-xl text-center shadow-sm">
              <div className="w-16 h-16 bg-blue-50 rounded-full flex items-center justify-center mb-4">
                <Swords className="w-8 h-8 text-blue-500" />
              </div>
              <p className="text-lg font-semibold text-gray-900">No open challenges</p>
              <p className="text-sm text-gray-500 mt-1 max-w-md">There are currently no challenges from external teams. Challenges will appear here when submitted.</p>
            </div>
          ) : challenges.map(c => (
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
              <button onClick={submitResult} disabled={submitting.result} className="flex-1 bg-primary text-white py-2 rounded-xl font-semibold disabled:opacity-70 disabled:cursor-not-allowed">
                {submitting.result ? 'Saving...' : 'Save Result'}
              </button>
              <button onClick={() => setResultFixture(null)} disabled={submitting.result} className="flex-1 border border-gray-300 py-2 rounded-xl text-gray-600 disabled:opacity-70 disabled:cursor-not-allowed">Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
