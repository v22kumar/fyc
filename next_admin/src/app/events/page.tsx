'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function AdminEventsPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [events, setEvents] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);
  
  // Form State
  const [formData, setFormData] = useState({
    title_ta: '5வது ஆண்டு விழா',
    title_en: '5th Anniversary Celebration',
    description_ta: 'விழா விளக்கம்',
    description_en: 'Event description',
    event_start: '2026-02-15T09:00:00Z',
    event_end: '2026-02-15T18:00:00Z',
    is_published: false,
    max_participants: 500,
    registration_deadline: '2026-02-10T23:59:59Z',
    competition_categories: 'Chess,Drawing,Speech'
  });

  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  const [registrations, setRegistrations] = useState<any[]>([]);
  const [analytics, setAnalytics] = useState<any>(null);

  const fetchEvents = async () => {
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    if (!token || !orgId) {
      router.push('/login');
      return;
    }

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/events/admin/all', {
        headers: {
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId,
        },
      });
      if (res.ok) {
        const data = await res.json();
        setEvents(data);
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
      fetchEvents();
    }
  }, [router]);

  const handleCreateEvent = async (e: React.FormEvent) => {
    e.preventDefault();
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');

    const cats = formData.competition_categories.split(',').map(c => c.trim()).filter(Boolean);

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/events', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId!,
        },
        body: JSON.stringify({
          ...formData,
          competition_categories: cats,
          max_participants: formData.max_participants ? parseInt(formData.max_participants as any) : null,
          registration_deadline: formData.registration_deadline || null
        }),
      });

      if (res.ok) {
        alert('Event successfully created!');
        setShowForm(false);
        fetchEvents();
      } else {
        const data = await res.json();
        alert(`Error: ${data.detail || JSON.stringify(data)}`);
      }
    } catch (err) {
      alert('Failed to connect to backend');
    }
  };

  const handleTogglePublish = async (ev: any) => {
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    try {
      await fetch(`http://127.0.0.1:8000/api/v1/events/${ev.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId!,
        },
        body: JSON.stringify({ is_published: !ev.is_published }),
      });
      fetchEvents();
    } catch (err) {
      alert('Error updating status');
    }
  };

  const loadEventDetails = async (id: string) => {
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    setSelectedEventId(id);
    try {
      const [regRes, anaRes] = await Promise.all([
        fetch(`http://127.0.0.1:8000/api/v1/events/${id}/registrations`, { headers: { 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId! } }),
        fetch(`http://127.0.0.1:8000/api/v1/events/${id}/analytics`, { headers: { 'Authorization': `Bearer ${token}`, 'X-Organization-ID': orgId! } })
      ]);
      
      if (regRes.ok) setRegistrations(await regRes.json());
      if (anaRes.ok) setAnalytics(await anaRes.json());
    } catch(err) {
      console.error(err);
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
          <a href="/events" style={{ ...styles.navItem, ...styles.navActive }}>📅 Events</a>
        </nav>
      </aside>

      <main style={styles.main}>
        <header style={styles.header}>
          <h2>📅 Event Management</h2>
          <button onClick={() => setShowForm(!showForm)} style={styles.btnNew}>
            {showForm ? 'Cancel' : '+ Create Event'}
          </button>
        </header>

        {showForm && (
          <div style={{ ...styles.card, marginBottom: '2rem' }}>
            <h3>Create New Event</h3>
            <form onSubmit={handleCreateEvent} style={styles.form}>
              <div style={styles.formRow}>
                <input placeholder="Title (EN)" value={formData.title_en} onChange={e => setFormData({...formData, title_en: e.target.value})} style={styles.input} required />
                <input placeholder="Title (TA)" value={formData.title_ta} onChange={e => setFormData({...formData, title_ta: e.target.value})} style={styles.input} required />
              </div>
              <textarea placeholder="Description" value={formData.description_en} onChange={e => setFormData({...formData, description_en: e.target.value})} style={styles.textarea} required />
              <textarea placeholder="Description (TA)" value={formData.description_ta} onChange={e => setFormData({...formData, description_ta: e.target.value})} style={styles.textarea} required />
              <div style={styles.formRow}>
                <label>Start: <input type="datetime-local" value={formData.event_start.slice(0,16)} onChange={e => setFormData({...formData, event_start: new Date(e.target.value).toISOString()})} style={styles.input} required /></label>
                <label>End: <input type="datetime-local" value={formData.event_end.slice(0,16)} onChange={e => setFormData({...formData, event_end: new Date(e.target.value).toISOString()})} style={styles.input} required /></label>
              </div>
              <div style={styles.formRow}>
                <input type="number" placeholder="Max Participants" value={formData.max_participants} onChange={e => setFormData({...formData, max_participants: parseInt(e.target.value)})} style={styles.input} />
                <label>Deadline: <input type="datetime-local" value={formData.registration_deadline.slice(0,16)} onChange={e => setFormData({...formData, registration_deadline: new Date(e.target.value).toISOString()})} style={styles.input} /></label>
              </div>
              <input placeholder="Categories (comma separated)" value={formData.competition_categories} onChange={e => setFormData({...formData, competition_categories: e.target.value})} style={styles.input} />
              
              <label><input type="checkbox" checked={formData.is_published} onChange={e => setFormData({...formData, is_published: e.target.checked})} /> Published</label>

              <button type="submit" style={styles.btnPrimary}>Create Event</button>
            </form>
          </div>
        )}

        {loading ? <div>Loading...</div> : (
          <div style={styles.grid}>
            {events.map(ev => (
              <div key={ev.id} style={styles.card}>
                <div style={{display: 'flex', justifyContent: 'space-between'}}>
                    <span style={styles.dateTag}>🗓️ {new Date(ev.event_start).toLocaleDateString()}</span>
                    <span style={{color: ev.is_published ? 'green' : 'orange'}}>{ev.is_published ? 'Published' : 'Draft'}</span>
                </div>
                <h3 style={{ marginTop: '0.75rem' }}>{ev.title_en}</h3>
                <p style={{ fontSize: '0.85rem', color: '#4b5563' }}>{ev.description_en}</p>
                <div style={{marginTop: 10}}>
                  <button onClick={() => handleTogglePublish(ev)} style={{...styles.qrBtn, marginRight: 10}}>{ev.is_published ? 'Unpublish' : 'Publish'}</button>
                  <button onClick={() => loadEventDetails(ev.id)} style={styles.btnPrimary}>Manage Registrations</button>
                </div>
              </div>
            ))}
          </div>
        )}

        {selectedEventId && analytics && (
          <div style={{...styles.card, marginTop: '2rem'}}>
            <h3>Registration Analytics</h3>
            <div style={{display: 'flex', gap: '2rem', marginBottom: '2rem'}}>
                <div>
                    <h4>Summary</h4>
                    <p>Total: {analytics.total_registrations}</p>
                </div>
                <div>
                    <h4>By Gender</h4>
                    <pre>{JSON.stringify(analytics.by_gender, null, 2)}</pre>
                </div>
                <div>
                    <h4>By Category</h4>
                    <pre>{JSON.stringify(analytics.by_competition, null, 2)}</pre>
                </div>
            </div>

            <h3>Registrations ({registrations.length})</h3>
            <table style={{width: '100%', textAlign: 'left', borderCollapse: 'collapse'}}>
                <thead>
                    <tr style={{borderBottom: '1px solid #ccc'}}>
                        <th>Name</th>
                        <th>Age</th>
                        <th>Phone</th>
                        <th>School</th>
                        <th>Categories</th>
                    </tr>
                </thead>
                <tbody>
                    {registrations.map((r, i) => (
                        <tr key={i} style={{borderBottom: '1px solid #eee'}}>
                            <td>{r.name}</td>
                            <td>{r.age}</td>
                            <td>{r.mobile_number}</td>
                            <td>{r.school_college}</td>
                            <td>{r.competition_category?.join(', ')}</td>
                        </tr>
                    ))}
                </tbody>
            </table>
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
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.5rem' },
  form: { display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1.25rem' },
  formRow: { display: 'flex', gap: '1.5rem' },
  input: { width: '100%', padding: '0.5rem', borderRadius: '6px', border: '1px solid #d1d5db' },
  textarea: { width: '100%', height: '60px', padding: '0.5rem', borderRadius: '6px', border: '1px solid #d1d5db' },
  btnPrimary: { backgroundColor: '#064e3b', color: '#ffffff', border: 'none', padding: '0.75rem 1.5rem', borderRadius: '8px', cursor: 'pointer' },
  dateTag: { fontSize: '0.8rem', backgroundColor: '#f3f4f6', padding: '0.25rem 0.5rem', borderRadius: '4px' },
  qrBtn: { backgroundColor: 'transparent', border: '1px solid #064e3b', color: '#064e3b', padding: '0.35rem 0.75rem', borderRadius: '6px', cursor: 'pointer' },
};
