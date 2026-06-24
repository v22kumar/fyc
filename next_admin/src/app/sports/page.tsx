'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function SportsAdminPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [tournaments, setTournaments] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);

  // Form State
  const [formData, setFormData] = useState({
    name_ta: 'கோடைக்கால கிரிக்கெட்',
    name_en: 'Summer Cricket Tournament',
    sport: 'cricket',
    year: new Date().getFullYear(),
    venue: 'FYC Ground',
    status: 'UPCOMING'
  });

  const [selectedTournament, setSelectedTournament] = useState<any>(null);
  const [teams, setTeams] = useState<any[]>([]);
  const [fixtures, setFixtures] = useState<any[]>([]);

  const fetchTournaments = async () => {
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    if (!token || !orgId) {
      router.push('/login');
      return;
    }
    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/sports/tournaments', {
        headers: { 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId }
      });
      if (res.ok) {
        setTournaments(await res.json());
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      router.push('/login');
    } else {
      setAuthorized(true);
      fetchTournaments();
    }
  }, [router]);

  const handleCreateTournament = async (e: React.FormEvent) => {
    e.preventDefault();
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/sports/tournaments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId! },
        body: JSON.stringify(formData),
      });
      if (res.ok) {
        alert('Tournament created!');
        setShowForm(false);
        fetchTournaments();
      } else {
        alert('Failed to create tournament');
      }
    } catch (err) {
      alert('Network error');
    }
  };

  const loadDetails = async (t: any) => {
    setSelectedTournament(t);
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    try {
      const [teamsRes, fixRes] = await Promise.all([
        fetch(`http://127.0.0.1:8000/api/v1/sports/tournaments/${t.id}/teams`, { headers: { 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId! } }),
        fetch(`http://127.0.0.1:8000/api/v1/sports/tournaments/${t.id}/fixtures`, { headers: { 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId! } })
      ]);
      if (teamsRes.ok) setTeams(await teamsRes.json());
      if (fixRes.ok) setFixtures(await fixRes.json());
    } catch (e) {
      console.error(e);
    }
  };

  const handleGenerateFixtures = async () => {
    if (!selectedTournament) return;
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    try {
      const res = await fetch(`http://127.0.0.1:8000/api/v1/sports/tournaments/${selectedTournament.id}/generate-fixtures?double_round=false`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId! }
      });
      if (res.ok) {
        alert('Fixtures generated successfully!');
        loadDetails(selectedTournament);
      } else {
        const data = await res.json();
        alert('Error: ' + data.detail);
      }
    } catch (err) {
      alert('Error connecting');
    }
  };

  if (!authorized) return null;

  return (
    <div style={styles.container}>
      <aside style={styles.sidebar}>
        <div style={styles.logoSec}>
          <span style={styles.logoBadge}>FYC</span>
          <span style={styles.logoTitle}>Admin Portal</span>
        </div>
        <nav style={styles.sideNav}>
          <a href="/dashboard" style={styles.navItem}>📊 Dashboard</a>
          <a href="/events" style={styles.navItem}>📅 Events</a>
          <a href="/sports" style={{ ...styles.navItem, ...styles.navActive }}>🏆 Sports</a>
        </nav>
      </aside>

      <main style={styles.main}>
        <header style={styles.header}>
          <h2>🏆 Sports & Tournaments</h2>
          <button onClick={() => setShowForm(!showForm)} style={styles.btnNew}>
            {showForm ? 'Cancel' : '+ New Tournament'}
          </button>
        </header>

        {showForm && (
          <div style={{ ...styles.card, marginBottom: '2rem' }}>
            <h3>Create Tournament</h3>
            <form onSubmit={handleCreateTournament} style={styles.form}>
              <div style={styles.formRow}>
                <input placeholder="Name (EN)" value={formData.name_en} onChange={e => setFormData({...formData, name_en: e.target.value})} style={styles.input} required />
                <input placeholder="Name (TA)" value={formData.name_ta} onChange={e => setFormData({...formData, name_ta: e.target.value})} style={styles.input} required />
              </div>
              <div style={styles.formRow}>
                <input placeholder="Sport (e.g. cricket, football)" value={formData.sport} onChange={e => setFormData({...formData, sport: e.target.value})} style={styles.input} required />
                <input type="number" placeholder="Year" value={formData.year} onChange={e => setFormData({...formData, year: parseInt(e.target.value)})} style={styles.input} required />
              </div>
              <div style={styles.formRow}>
                <input placeholder="Venue" value={formData.venue} onChange={e => setFormData({...formData, venue: e.target.value})} style={styles.input} required />
                <select value={formData.status} onChange={e => setFormData({...formData, status: e.target.value})} style={styles.input}>
                  <option value="UPCOMING">Upcoming</option>
                  <option value="ONGOING">Ongoing</option>
                  <option value="COMPLETED">Completed</option>
                </select>
              </div>
              <button type="submit" style={{...styles.btnPrimary, width: '200px'}}>Create</button>
            </form>
          </div>
        )}

        <div style={styles.grid}>
          {tournaments.map(t => (
            <div key={t.id} style={styles.card}>
              <span style={{ fontSize: '0.8rem', color: '#064e3b', fontWeight: 'bold' }}>{t.status}</span>
              <h3 style={{ marginTop: '0.5rem' }}>{t.name_en}</h3>
              <p style={{ color: '#4b5563', fontSize: '0.9rem' }}>Sport: {t.sport.toUpperCase()} | {t.year}</p>
              <button onClick={() => loadDetails(t)} style={{...styles.btnPrimary, marginTop: '1rem', width: '100%'}}>Manage</button>
            </div>
          ))}
        </div>

        {selectedTournament && (
          <div style={{...styles.card, marginTop: '2rem'}}>
            <h3>{selectedTournament.name_en} - Management</h3>
            
            <div style={{display: 'flex', gap: '3rem', marginTop: '1.5rem'}}>
              <div style={{flex: 1}}>
                <h4>Registered Teams ({teams.length})</h4>
                <ul style={{ listStyle: 'none', padding: 0 }}>
                  {teams.map(tm => (
                    <li key={tm.id} style={{ padding: '0.75rem', borderBottom: '1px solid #eee' }}>
                      <strong>{tm.name}</strong> <br/>
                      <span style={{fontSize: '0.85rem', color: '#6b7280'}}>Captain: {tm.captain_name} | Contact: {tm.contact_number}</span>
                    </li>
                  ))}
                  {teams.length === 0 && <p style={{color: '#999'}}>No teams registered yet.</p>}
                </ul>
              </div>

              <div style={{flex: 1}}>
                <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center'}}>
                  <h4>Fixtures ({fixtures.length})</h4>
                  {fixtures.length === 0 && teams.length >= 2 && (
                    <button onClick={handleGenerateFixtures} style={{...styles.btnPrimary, padding: '0.5rem 1rem'}}>Auto-Generate Fixtures</button>
                  )}
                </div>
                <ul style={{ listStyle: 'none', padding: 0, marginTop: '1rem' }}>
                  {fixtures.map(f => (
                    <li key={f.id} style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: '8px', marginBottom: '0.5rem', background: '#f9fafb' }}>
                      <div style={{fontSize: '0.8rem', color: '#6b7280', marginBottom: '0.2rem'}}>Match #{f.match_number} - {f.status}</div>
                      <strong>{f.team_a_name}</strong> vs <strong>{f.team_b_name}</strong>
                    </li>
                  ))}
                  {fixtures.length === 0 && <p style={{color: '#999'}}>No fixtures generated yet.</p>}
                </ul>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: { display: 'flex', minHeight: '100vh', fontFamily: 'sans-serif' },
  sidebar: { width: '260px', backgroundColor: '#064e3b', color: '#ffffff', padding: '2rem 1.5rem', display: 'flex', flexDirection: 'column' },
  logoSec: { display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '3rem' },
  logoBadge: { backgroundColor: '#eab308', color: '#064e3b', fontWeight: 800, padding: '0.2rem 0.5rem', borderRadius: '4px' },
  logoTitle: { fontWeight: 700, fontSize: '1.1rem' },
  sideNav: { display: 'flex', flexDirection: 'column', gap: '0.5rem' },
  navItem: { color: '#a7f3d0', textDecoration: 'none', padding: '0.75rem 1rem', borderRadius: '8px', transition: 'all 0.2s' },
  navActive: { backgroundColor: '#0f5132', color: '#ffffff', fontWeight: 600 },
  main: { flexGrow: 1, padding: '2.5rem', backgroundColor: '#f3f4f6' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2.5rem', borderBottom: '1px solid #e5e7eb', paddingBottom: '1rem' },
  btnNew: { backgroundColor: '#064e3b', color: '#ffffff', border: 'none', padding: '0.65rem 1.25rem', borderRadius: '8px', cursor: 'pointer' },
  card: { backgroundColor: '#ffffff', borderRadius: '16px', border: '1px solid #e5e7eb', padding: '1.5rem' },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' },
  form: { display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1.25rem' },
  formRow: { display: 'flex', gap: '1.5rem' },
  input: { width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid #d1d5db' },
  btnPrimary: { backgroundColor: '#064e3b', color: '#ffffff', border: 'none', padding: '0.75rem 1.5rem', borderRadius: '8px', cursor: 'pointer' },
};
