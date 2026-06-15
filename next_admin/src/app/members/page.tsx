'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface Member {
  id: string;
  phone_number: string;
  role: string;
  is_verified: boolean;
  name: string;
  membership_number?: string;
  designation?: string;
}

export default function AdminMembersPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [members, setMembers] = useState<Member[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState<Member | null>(null);
  const [designationTa, setDesignationTa] = useState('உறுப்பினர்');
  const [designationEn, setDesignationEn] = useState('Member');
  const [expiryDate, setExpiryDate] = useState('2027-12-31T23:59:59Z');
  const [loading, setLoading] = useState(true);

  // Mock list of users for local demonstration that can be upgraded
  const mockMembers: Member[] = [
    { id: 'e30d7b27-5d07-4c7a-bc12-f04bf4c86e00', phone_number: '+919876543210', role: 'SUPER_ADMIN', is_verified: true, name: 'Super Administrator', membership_number: 'FYC-2026-0001', designation: 'Super Admin' },
    { id: '30db2a45-6677-4c7b-b89a-8eefc8c11aa9', phone_number: '+919876543211', role: 'VOLUNTEER', is_verified: true, name: 'Karthik J' },
    { id: '40fb2a45-6677-4c7b-b89a-8eefc8c11ab1', phone_number: '+919876543212', role: 'CLUB_MEMBER', is_verified: true, name: 'Meena R' },
  ];

  const fetchMembers = async () => {
    // Usually fetches from backend. We initialize with mock data for complete visual demo.
    setMembers(mockMembers);
    setLoading(false);
  };

  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      router.push('/login');
    } else {
      setAuthorized(true);
      fetchMembers();
    }
  }, [router]);

  const handleIssueCard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser) return;
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/membership/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId!,
        },
        body: JSON.stringify({
          user_id: selectedUser.id,
          designation_ta: designationTa,
          designation_en: designationEn,
          expires_at: expiryDate,
        }),
      });

      const data = await res.json();
      if (res.ok) {
        alert(`Membership card successfully generated: ${data.membership_number}`);
        setShowModal(false);
        // Update local list
        setMembers(prev => prev.map(m => m.id === selectedUser.id ? { ...m, membership_number: data.membership_number, designation: designationEn } : m));
      } else {
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
          <a href="/members" style={{ ...styles.navItem, ...styles.navActive }}>👥 Members & Approvals</a>
          <a href="/events" style={styles.navItem}>📅 Events Planner</a>
        </nav>
      </aside>

      {/* Main Content Area */}
      <main style={styles.main}>
        <header style={styles.header}>
          <h2>👥 Membership & Approvals Management</h2>
          <div style={styles.orgTag}>Org Scope: Friends Youth Club</div>
        </header>

        {loading ? (
          <div>Loading members directory...</div>
        ) : (
          <div style={styles.card}>
            <table style={styles.table}>
              <thead>
                <tr style={styles.thRow}>
                  <th style={styles.th}>Name</th>
                  <th style={styles.th}>Phone</th>
                  <th style={styles.th}>Role</th>
                  <th style={styles.th}>ID Card Status</th>
                  <th style={styles.th}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {members.map(member => (
                  <tr key={member.id} style={styles.tr}>
                    <td style={styles.td}>{member.name}</td>
                    <td style={styles.td}>{member.phone_number}</td>
                    <td style={styles.td}>{member.role}</td>
                    <td style={styles.td}>
                      {member.membership_number ? (
                        <span style={styles.badgeSuccess}>Issued ({member.membership_number})</span>
                      ) : (
                        <span style={styles.badgeWarning}>Pending</span>
                      )}
                    </td>
                    <td style={styles.td}>
                      {!member.membership_number && (
                        <button
                          onClick={() => {
                            setSelectedUser(member);
                            setShowModal(true);
                          }}
                          style={styles.actionBtn}
                        >
                          Issue ID Card
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>

      {/* Modal Dialog */}
      {showModal && selectedUser && (
        <div style={styles.modalBackdrop}>
          <div style={styles.modalCard}>
            <h3>Issue Digital ID Card</h3>
            <p style={{ fontSize: '0.85rem', color: '#6b7280', margin: '0.5rem 0 1.5rem' }}>
              Generating card for: {selectedUser.name}
            </p>
            <form onSubmit={handleIssueCard} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={styles.label}>Designation (Tamil)</label>
                <input
                  type="text"
                  value={designationTa}
                  onChange={(e) => setDesignationTa(e.target.value)}
                  style={styles.input}
                  required
                />
              </div>
              <div>
                <label style={styles.label}>Designation (English)</label>
                <input
                  type="text"
                  value={designationEn}
                  onChange={(e) => setDesignationEn(e.target.value)}
                  style={styles.input}
                  required
                />
              </div>
              <div>
                <label style={styles.label}>Expires At</label>
                <input
                  type="text"
                  value={expiryDate}
                  onChange={(e) => setExpiryDate(e.target.value)}
                  style={styles.input}
                  required
                />
              </div>
              <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem' }}>
                <button type="submit" style={styles.btnPrimary}>Generate & Save</button>
                <button type="button" onClick={() => setShowModal(false)} style={styles.btnCancel}>Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
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
  orgTag: {
    backgroundColor: '#d1fae5',
    color: '#065f46',
    padding: '0.35rem 0.75rem',
    borderRadius: '12px',
    fontSize: '0.85rem',
    fontWeight: 600,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: '16px',
    border: '1px solid #e5e7eb',
    padding: '1.5rem',
    boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    textAlign: 'left',
  },
  thRow: {
    borderBottom: '2px solid #e5e7eb',
  },
  th: {
    padding: '1rem',
    fontSize: '0.85rem',
    fontWeight: 600,
    color: '#374151',
  },
  tr: {
    borderBottom: '1px solid #e5e7eb',
    fontSize: '0.9rem',
  },
  td: {
    padding: '1rem',
  },
  badgeSuccess: {
    backgroundColor: '#d1fae5',
    color: '#065f46',
    padding: '0.2rem 0.5rem',
    borderRadius: '6px',
    fontSize: '0.75rem',
    fontWeight: 600,
  },
  badgeWarning: {
    backgroundColor: '#fef3c7',
    color: '#92400e',
    padding: '0.2rem 0.5rem',
    borderRadius: '6px',
    fontSize: '0.75rem',
    fontWeight: 600,
  },
  actionBtn: {
    backgroundColor: '#064e3b',
    color: '#ffffff',
    border: 'none',
    padding: '0.4rem 0.8rem',
    borderRadius: '6px',
    fontWeight: 600,
    fontSize: '0.8rem',
    cursor: 'pointer',
  },
  modalBackdrop: {
    position: 'fixed',
    top: 0,
    left: 0,
    width: '100vw',
    height: '100vh',
    backgroundColor: 'rgba(0,0,0,0.5)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  modalCard: {
    backgroundColor: '#ffffff',
    padding: '2rem',
    borderRadius: '16px',
    width: '90%',
    maxWidth: '400px',
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
  btnPrimary: {
    backgroundColor: '#064e3b',
    color: '#ffffff',
    border: 'none',
    padding: '0.6rem 1rem',
    borderRadius: '8px',
    fontWeight: 600,
    cursor: 'pointer',
  },
  btnCancel: {
    backgroundColor: 'transparent',
    border: '1px solid #d1d5db',
    color: '#374151',
    padding: '0.6rem 1rem',
    borderRadius: '8px',
    fontWeight: 600,
    cursor: 'pointer',
  },
};
