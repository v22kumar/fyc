'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function DashboardPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [stats, setStats] = useState({
    users: 500,
    donors: 200,
    issuesRaised: 100,
    issuesResolved: 75,
    events: 25,
    members: 100,
  });

  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      router.push('/login');
    } else {
      setAuthorized(true);
    }
  }, [router]);

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_org_id');
    localStorage.removeItem('admin_role');
    router.push('/login');
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
          <a href="/dashboard" style={{ ...styles.navItem, ...styles.navActive }}>📊 Dashboard</a>
          <a href="/issues" style={styles.navItem}>⚠️ Public Issues</a>
          <a href="/members" style={styles.navItem}>👥 Members & Approvals</a>
          <a href="/events" style={styles.navItem}>📅 Events Planner</a>
        </nav>
        <button onClick={handleLogout} style={styles.logoutBtn}>Logout</button>
      </aside>

      {/* Main Content Area */}
      <main style={styles.main}>
        <header style={styles.header}>
          <h2>📊 Analytics & Impact Dashboard</h2>
          <div style={styles.orgTag}>Org Scope: Friends Youth Club</div>
        </header>

        {/* Stats Grid (SNO-010) */}
        <section style={styles.statsGrid}>
          <div style={styles.statCard}>
            <h3>Registered Citizens</h3>
            <div style={styles.statNumber}>{stats.users}</div>
            <p>Target: 500 Users</p>
          </div>
          
          <div style={styles.statCard}>
            <h3>Blood Donors</h3>
            <div style={{ ...styles.statNumber, color: '#991b1b' }}>{stats.donors}</div>
            <p>Target: 200 Donors</p>
          </div>

          <div style={styles.statCard}>
            <h3>Issues Resolved</h3>
            <div style={styles.statNumber}>{stats.issuesResolved} / {stats.issuesRaised}</div>
            <p>75% Resolution Rate</p>
          </div>

          <div style={styles.statCard}>
            <h3>Active Club Members</h3>
            <div style={styles.statNumber}>{stats.members}</div>
            <p>Designated committee members</p>
          </div>
        </section>

        {/* System Status */}
        <section style={styles.card}>
          <h3>⚡ Quick Administration Actions</h3>
          <div style={styles.actionGrid}>
            <a href="/issues" style={styles.actionCard}>
              <h4>Triage Public Issues</h4>
              <p>Assign reported roads and streetlight complaints to volunteers.</p>
            </a>
            <a href="/members" style={styles.actionCard}>
              <h4>Approve Memberships</h4>
              <p>Review and issue Digital ID QR cards to pending member registrations.</p>
            </a>
          </div>
        </section>
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
    justifyContent: 'space-between',
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
    flexGrow: 1,
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
  logoutBtn: {
    backgroundColor: 'transparent',
    border: '1px solid #fecaca',
    color: '#fecaca',
    padding: '0.65rem',
    borderRadius: '8px',
    cursor: 'pointer',
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
  orgTag: {
    backgroundColor: '#d1fae5',
    color: '#065f46',
    padding: '0.35rem 0.75rem',
    borderRadius: '12px',
    fontSize: '0.85rem',
    fontWeight: 600,
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
    gap: '1.5rem',
    marginBottom: '2.5rem',
  },
  statCard: {
    backgroundColor: '#ffffff',
    padding: '1.5rem',
    borderRadius: '12px',
    border: '1px solid #e5e7eb',
    boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
  },
  statNumber: {
    fontSize: '2.25rem',
    fontWeight: 800,
    color: '#064e3b',
    margin: '0.5rem 0',
  },
  card: {
    backgroundColor: '#ffffff',
    padding: '2rem',
    borderRadius: '12px',
    border: '1px solid #e5e7eb',
  },
  actionGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '1.5rem',
    marginTop: '1.5rem',
  },
  actionCard: {
    border: '1px solid #e5e7eb',
    borderRadius: '8px',
    padding: '1.25rem',
    textDecoration: 'none',
    color: 'inherit',
    transition: 'all 0.2s',
  },
};

