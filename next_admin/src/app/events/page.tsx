'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface ClubEvent {
  id: string;
  title_ta: string;
  title_en: string;
  description_ta: string;
  description_en: string;
  event_start: string;
  event_end: string;
  banner_url?: string;
}

export default function AdminEventsPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [events, setEvents] = useState<ClubEvent[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [titleTa, setTitleTa] = useState('சுதந்திர தின விழா');
  const [titleEn, setTitleEn] = useState('Independence Day Celebration');
  const [descTa, setDescTa] = useState('பிரண்ட்ஸ் யூத் கிளப் 26வது சுதந்திர தின கொண்டாட்டம்.');
  const [descEn, setDescEn] = useState('FYC 26th Independence Day flag hoisting and welfare distribution.');
  const [start, setStart] = useState('2026-08-15T09:00:00Z');
  const [end, setEnd] = useState('2026-08-15T12:00:00Z');
  const [loading, setLoading] = useState(true);

  const fetchEvents = async () => {
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    if (!token || !orgId) {
      router.push('/login');
      return;
    }

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/events', {
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
      // Fallback mock events for standalone visual demo
      setEvents([
        { id: '1', title_ta: 'சுதந்திர தின விழா', title_en: 'Independence Day Celebration', description_ta: '26வது கொண்டாட்டம்', description_en: '26th Celebration', event_start: '2026-08-15T09:00:00Z', event_end: '2026-08-15T12:00:00Z' },
        { id: '2', title_ta: 'மரம் நடும் விழா', title_en: 'Tree Plantation Drive', description_ta: 'பசுமை நாகர்கோவில்', description_en: 'Green Nagercoil saplings plantation', event_start: '2026-08-25T07:00:00Z', event_end: '2026-08-25T11:00:00Z' },
      ]);
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

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/events', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId!,
        },
        body: JSON.stringify({
          title_ta: titleTa,
          title_en: titleEn,
          description_ta: descTa,
          description_en: descEn,
          event_start: start,
          event_end: end,
        }),
      });

      if (res.ok) {
        alert('Event successfully planned!');
        setShowForm(false);
        fetchEvents();
      } else {
        const data = await res.json();
        alert(`Error: ${data.detail}`);
      }
    } catch (err) {
      alert('Failed to connect to backend');
    }
  };

  if (!authorized) return null;

  return (
    <div style={styles.container}>
      {/* Sidebar */}
      <aside style={styles.sidebar}>
        <div style={styles.logoSec}>
          <span style={styles.logoBadge}>FYC</span>
          <span style={styles.logoTitle}>Admin Portal</span>
        </div>
        <nav style={styles.sideNav}>
          <a href="/dashboard" style={styles.navItem}>📊 Dashboard</a>
          <a href="/issues" style={styles.navItem}>⚠️ Public Issues</a>
          <a href="/members" style={styles.navItem}>👥 Members & Approvals</a>
          <a href="/events" style={{ ...styles.navItem, ...styles.navActive }}>📅 Events Planner</a>
        </nav>
      </aside>

      {/* Main Content Area */}
      <main style={styles.main}>
        <header style={styles.header}>
          <h2>📅 Events Planner & Attendance Tracking</h2>
          <button onClick={() => setShowForm(!showForm)} style={styles.btnNew}>
            {showForm ? 'Cancel' : '+ Plan New Event'}
          </button>
        </header>

        {showForm && (
          <div style={{ ...styles.card, marginBottom: '2rem' }}>
            <h3>Create New Club Event</h3>
            <form onSubmit={handleCreateEvent} style={styles.form}>
              <div style={styles.formRow}>
                <div style={{ flex: 1 }}>
                  <label style={styles.label}>Title (Tamil)</label>
                  <input type="text" value={titleTa} onChange={(e) => setTitleTa(e.target.value)} style={styles.input} required />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={styles.label}>Title (English)</label>
                  <input type="text" value={titleEn} onChange={(e) => setTitleEn(e.target.value)} style={styles.input} required />
                </div>
              </div>
              <div>
                <label style={styles.label}>Description (Tamil)</label>
                <textarea value={descTa} onChange={(e) => setDescTa(e.target.value)} style={styles.textarea} required />
              </div>
              <div>
                <label style={styles.label}>Description (English)</label>
                <textarea value={descEn} onChange={(e) => setDescEn(e.target.value)} style={styles.textarea} required />
              </div>
              <div style={styles.formRow}>
                <div style={{ flex: 1 }}>
                  <label style={styles.label}>Start Time (ISO)</label>
                  <input type="text" value={start} onChange={(e) => setStart(e.target.value)} style={styles.input} required />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={styles.label}>End Time (ISO)</label>
                  <input type="text" value={end} onChange={(e) => setEnd(e.target.value)} style={styles.input} required />
                </div>
              </div>
              <button type="submit" style={styles.btnPrimary}>Plan Event & Publish</button>
            </form>
          </div>
        )}

        {loading ? (
          <div>Loading scheduled events...</div>
        ) : (
          <div style={styles.grid}>
            {events.map(ev => (
              <div key={ev.id} style={styles.card}>
                <span style={styles.dateTag}>🗓️ {new Date(ev.event_start).toLocaleDateString()}</span>
                <h3 style={{ marginTop: '0.75rem', color: '#064e3b' }}>{ev.title_en}</h3>
                <p style={{ fontSize: '0.85rem', color: '#4b5563', margin: '0.5rem 0 1.5rem' }}>{ev.description_en}</p>
                <div style={styles.footerRow}>
                  <span>🕒 {new Date(ev.event_start).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</span>
                  <button onClick={() => alert(`QR Attendance scanner payload: FYC:EVENT_CHECKIN:${ev.id}`)} style={styles.qrBtn}>
                    View Check-in QR Code
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex',
    minHeight: '100vh',
  },
  sidebar: {
    width: '260px',
    backgroundColor: '#064e3b',
    color: '#ffffff',
    padding: '2rem 1.5rem',
    display: 'flex',
    flexDirection: 'column',
  },
  logoSec: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
    marginBottom: '3rem',
  },
  logoBadge: {
    backgroundColor: '#eab308',
    color: '#064e3b',
    fontWeight: 800,
    padding: '0.2rem 0.5rem',
    borderRadius: '4px',
    fontSize: '0.8rem',
  },
  logoTitle: {
    fontWeight: 700,
    fontSize: '1.1rem',
    fontFamily: 'Outfit, sans-serif',
  },
  sideNav: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.5rem',
  },
  navItem: {
    color: '#a7f3d0',
    textDecoration: 'none',
    padding: '0.75rem 1rem',
    borderRadius: '8px',
    fontSize: '0.95rem',
    transition: 'all 0.2s',
  },
  navActive: {
    backgroundColor: '#0f5132',
    color: '#ffffff',
    fontWeight: 600,
  },
  main: {
    flexGrow: 1,
    padding: '2.5rem',
    backgroundColor: '#f3f4f6',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '2.5rem',
    borderBottom: '1px solid #e5e7eb',
    paddingBottom: '1rem',
  },
  btnNew: {
    backgroundColor: '#064e3b',
    color: '#ffffff',
    border: 'none',
    padding: '0.65rem 1.25rem',
    borderRadius: '8px',
    fontWeight: 600,
    cursor: 'pointer',
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: '16px',
    border: '1px solid #e5e7eb',
    padding: '1.5rem',
    boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
    gap: '1.5rem',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
    marginTop: '1.25rem',
  },
  formRow: {
    display: 'flex',
    gap: '1.5rem',
  },
  label: {
    display: 'block',
    fontSize: '0.8rem',
    fontWeight: 600,
    marginBottom: '0.25rem',
  },
  input: {
    width: '100%',
    padding: '0.5rem',
    borderRadius: '6px',
    border: '1px solid #d1d5db',
  },
  textarea: {
    width: '100%',
    height: '60px',
    padding: '0.5rem',
    borderRadius: '6px',
    border: '1px solid #d1d5db',
    resize: 'vertical',
  },
  btnPrimary: {
    backgroundColor: '#064e3b',
    color: '#ffffff',
    border: 'none',
    padding: '0.75rem 1.5rem',
    borderRadius: '8px',
    fontWeight: 600,
    cursor: 'pointer',
    alignSelf: 'flex-start',
  },
  dateTag: {
    fontSize: '0.8rem',
    backgroundColor: '#f3f4f6',
    padding: '0.25rem 0.5rem',
    borderRadius: '4px',
    fontWeight: 600,
    color: '#4b5563',
  },
  footerRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderTop: '1px solid #f3f4f6',
    paddingTop: '0.75rem',
    fontSize: '0.85rem',
    color: '#6b7280',
  },
  qrBtn: {
    backgroundColor: 'transparent',
    border: '1px solid #064e3b',
    color: '#064e3b',
    padding: '0.35rem 0.75rem',
    borderRadius: '6px',
    fontWeight: 600,
    fontSize: '0.75rem',
    cursor: 'pointer',
  },
};
