'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface PublicIssue {
  id: string;
  category: string;
  description_ta: string;
  description_en: string;
  status: string;
  latitude: number;
  longitude: number;
  photo_url: string;
  assigned_volunteer_id: string | null;
  created_at: string;
}

export default function AdminIssuesPage() {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);
  const [issues, setIssues] = useState<PublicIssue[]>([]);
  const [selectedIssue, setSelectedIssue] = useState<PublicIssue | null>(null);
  const [loading, setLoading] = useState(true);

  // Load issues from FastAPI
  const fetchIssues = async () => {
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');
    if (!token || !orgId) {
      router.push('/login');
      return;
    }

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/issues', {
        headers: {
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId,
        },
      });
      if (res.ok) {
        const data = await res.json();
        setIssues(data);
        if (data.length > 0) setSelectedIssue(data[0]);
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
      fetchIssues();
    }
  }, [router]);

  // Update Status (State Machine - SNO-008)
  const handleUpdateStatus = async (status: string, volunteerId: string | null = null) => {
    if (!selectedIssue) return;
    const token = localStorage.getItem('admin_token');
    const orgId = localStorage.getItem('admin_org_id');

    try {
      const payload: Record<string, any> = { status };
      if (volunteerId) payload.assigned_volunteer_id = volunteerId;

      const res = await fetch(`http://127.0.0.1:8000/api/v1/issues/${selectedIssue.id}/status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Organization-ID': orgId!,
        },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        alert(`Issue status successfully updated to ${status}`);
        fetchIssues(); // Reload
      } else {
        const err = await res.json();
        alert(`Error: ${err.detail}`);
      }
    } catch (err) {
      alert('Network request failed');
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
          <a href="/issues" style={{ ...styles.navItem, ...styles.navActive }}>⚠️ Public Issues</a>
          <a href="/members" style={styles.navItem}>👥 Members & Approvals</a>
          <a href="/events" style={styles.navItem}>📅 Events Planner</a>
        </nav>
      </aside>

      {/* Main Content Area */}
      <main style={styles.main}>
        <header style={styles.header}>
          <h2>⚠️ Public Issues Triage Management</h2>
          <div style={styles.orgTag}>Org Scope: Friends Youth Club</div>
        </header>

        {loading ? (
          <div>Loading reported issues...</div>
        ) : (
          <div style={styles.splitLayout}>
            {/* Issues List */}
            <div style={styles.listSection}>
              {issues.length === 0 ? (
                <p>No issues reported under this organization.</p>
              ) : (
                issues.map(issue => (
                  <div
                    key={issue.id}
                    onClick={() => setSelectedIssue(issue)}
                    style={{
                      ...styles.issueRow,
                      ...(selectedIssue?.id === issue.id ? styles.issueRowSelected : {}),
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={styles.categoryBadge}>{issue.category}</span>
                      <span style={{ ...styles.statusBadge, ...getStatusColor(issue.status) }}>{issue.status}</span>
                    </div>
                    <p style={styles.descTrunc}>{issue.description_en}</p>
                    <small style={{ color: '#9ca3af' }}>{new Date(issue.created_at).toLocaleDateString()}</small>
                  </div>
                ))
              )}
            </div>

            {/* Issue Detail Panel */}
            {selectedIssue && (
              <div style={styles.detailCard}>
                <h3 style={{ borderBottom: '1px solid #e5e7eb', paddingBottom: '0.5rem', marginBottom: '1rem' }}>
                  Issue details
                </h3>
                <div style={styles.detailMeta}>
                  <p><strong>Category:</strong> {selectedIssue.category}</p>
                  <p><strong>Status:</strong> {selectedIssue.status}</p>
                  <p><strong>Coordinates:</strong> {selectedIssue.latitude.toFixed(4)}, {selectedIssue.longitude.toFixed(4)}</p>
                  <p><strong>Tamil Description:</strong> {selectedIssue.description_ta}</p>
                  <p><strong>English Description:</strong> {selectedIssue.description_en}</p>
                </div>

                {/* Workflow Action Board */}
                <div style={styles.actionBlock}>
                  <h4>Execute State Machine Transition</h4>
                  <div style={styles.actionBtns}>
                    {selectedIssue.status === 'NEW' && (
                      <button
                        onClick={() => handleUpdateStatus('ASSIGNED', 'e30d7b27-5d07-4c7a-bc12-f04bf4c86e00')}
                        style={styles.btnAction}
                      >
                        Assign to Volunteer
                      </button>
                    )}
                    {(selectedIssue.status === 'ASSIGNED' || selectedIssue.status === 'UNDER_REVIEW') && (
                      <>
                        <button
                          onClick={() => handleUpdateStatus('UNDER_REVIEW')}
                          style={styles.btnAction}
                        >
                          Mark Under Review
                        </button>
                        <button
                          onClick={() => handleUpdateStatus('RESOLVED')}
                          style={{ ...styles.btnAction, backgroundColor: '#059669' }}
                        >
                          Mark Resolved
                        </button>
                      </>
                    )}
                    {selectedIssue.status === 'RESOLVED' && (
                      <button
                        onClick={() => handleUpdateStatus('CLOSED')}
                        style={{ ...styles.btnAction, backgroundColor: '#111827' }}
                      >
                        Close Issue
                      </button>
                    )}
                    {['NEW', 'ASSIGNED', 'UNDER_REVIEW'].includes(selectedIssue.status) && (
                      <button
                        onClick={() => handleUpdateStatus('REJECTED')}
                        style={{ ...styles.btnAction, backgroundColor: '#dc2626' }}
                      >
                        Reject Complaint
                      </button>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}

function getStatusColor(status: string) {
  switch (status) {
    case 'NEW': return { backgroundColor: '#dbeafe', color: '#1e40af' };
    case 'ASSIGNED': return { backgroundColor: '#f3e8ff', color: '#6b21a8' };
    case 'UNDER_REVIEW': return { backgroundColor: '#ffedd5', color: '#9a3412' };
    case 'RESOLVED': return { backgroundColor: '#dcfce7', color: '#166534' };
    case 'CLOSED': return { backgroundColor: '#f3f4f6', color: '#374151' };
    default: return { backgroundColor: '#fca5a5', color: '#991b1b' };
  }
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
  splitLayout: {
    display: 'grid',
    gridTemplateColumns: '1.2fr 1.8fr',
    gap: '2rem',
    alignItems: 'start',
  },
  listSection: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
    overflowY: 'auto',
    maxHeight: 'calc(100vh - 200px)',
  },
  issueRow: {
    backgroundColor: '#ffffff',
    padding: '1.25rem',
    borderRadius: '12px',
    border: '1px solid #e5e7eb',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
  issueRowSelected: {
    borderColor: '#064e3b',
    boxShadow: '0 0 0 2px rgba(6, 78, 59, 0.1)',
  },
  categoryBadge: {
    fontSize: '0.75rem',
    fontWeight: 700,
    color: '#064e3b',
  },
  statusBadge: {
    fontSize: '0.75rem',
    padding: '0.1rem 0.5rem',
    borderRadius: '4px',
    fontWeight: 700,
  },
  descTrunc: {
    fontSize: '0.9rem',
    color: '#4b5563',
    margin: '0.5rem 0',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  detailCard: {
    backgroundColor: '#ffffff',
    padding: '2rem',
    borderRadius: '16px',
    border: '1px solid #e5e7eb',
    boxShadow: '0 4px 6px rgba(0,0,0,0.02)',
  },
  detailMeta: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.75rem',
    fontSize: '0.95rem',
    color: '#374151',
    marginBottom: '2rem',
  },
  actionBlock: {
    borderTop: '1px solid #e5e7eb',
    paddingTop: '1.5rem',
  },
  actionBtns: {
    display: 'flex',
    gap: '0.75rem',
    flexWrap: 'wrap',
    marginTop: '1rem',
  },
  btnAction: {
    backgroundColor: '#2563eb',
    color: '#ffffff',
    border: 'none',
    padding: '0.6rem 1rem',
    borderRadius: '8px',
    fontWeight: 600,
    fontSize: '0.85rem',
    cursor: 'pointer',
  },
};
