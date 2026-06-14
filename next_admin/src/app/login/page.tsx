'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [orgId, setOrgId] = useState('8f8b80b7-4b71-4770-b183-5c5f49e49a1d'); // Seeded Org ID
  const [username, setUsername] = useState('+919876543210'); // Seeded Superadmin phone
  const [password, setPassword] = useState('supersecureadminpassword123'); // Seeded password
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/auth/login/password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          organization_id: orgId,
          username,
          password,
        }),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.detail || 'Login failed');
      }

      // Save token & org ID
      localStorage.setItem('admin_token', data.access_token);
      localStorage.setItem('admin_org_id', orgId);
      localStorage.setItem('admin_role', data.user.role);
      
      router.push('/dashboard');
    } catch (err: any) {
      setError(err.message || 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.loginCard}>
        <div style={styles.header}>
          <span style={styles.logoBadge}>FYC</span>
          <h1 style={styles.title}>FYC CONNECT</h1>
          <p style={styles.subtitle}>Administration Portal</p>
        </div>

        <form onSubmit={handleSubmit} style={styles.form}>
          {error && <div style={styles.errorAlert}>{error}</div>}

          <div style={styles.formGroup}>
            <label style={styles.label}>Organization ID (UUID)</label>
            <input
              type="text"
              value={orgId}
              onChange={(e) => setOrgId(e.target.value)}
              style={styles.input}
              required
            />
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label}>Username (Email or Phone)</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              style={styles.input}
              required
            />
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label}>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={styles.input}
              required
            />
          </div>

          <button type="submit" disabled={loading} style={styles.submitBtn}>
            {loading ? 'Logging in...' : 'Access Admin Dashboard'}
          </button>
        </form>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '100vh',
    backgroundColor: '#f3f4f6',
  },
  loginCard: {
    backgroundColor: '#ffffff',
    padding: '2.5rem',
    borderRadius: '16px',
    boxShadow: '0 10px 15px rgba(0,0,0,0.05), 0 4px 6px rgba(0,0,0,0.05)',
    width: '100%',
    maxWidth: '450px',
    border: '1px solid #e5e7eb',
  },
  header: {
    textAlign: 'center',
    marginBottom: '2rem',
  },
  logoBadge: {
    backgroundColor: '#eab308',
    backgroundImage: 'linear-gradient(135deg, #eab308, #064e3b)',
    color: '#ffffff',
    padding: '0.25rem 0.65rem',
    borderRadius: '6px',
    fontSize: '0.9rem',
    fontWeight: 800,
    display: 'inline-block',
    marginBottom: '0.5rem',
  },
  title: {
    fontSize: '1.75rem',
    fontWeight: 700,
    fontFamily: 'Outfit, sans-serif',
    color: '#064e3b',
  },
  subtitle: {
    color: '#6b7280',
    fontSize: '0.85rem',
    marginTop: '0.25rem',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1.25rem',
  },
  errorAlert: {
    backgroundColor: '#fef2f2',
    border: '1px solid #fecaca',
    color: '#991b1b',
    padding: '0.75rem',
    borderRadius: '8px',
    fontSize: '0.85rem',
    fontWeight: 600,
  },
  formGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.35rem',
  },
  label: {
    fontSize: '0.8rem',
    fontWeight: 600,
    color: '#374151',
  },
  input: {
    padding: '0.65rem',
    borderRadius: '8px',
    border: '1px solid #d1d5db',
    fontSize: '0.95rem',
    outline: 'none',
  },
  submitBtn: {
    backgroundColor: '#064e3b',
    color: '#ffffff',
    padding: '0.85rem',
    borderRadius: '8px',
    border: 'none',
    fontWeight: 600,
    fontSize: '0.95rem',
    cursor: 'pointer',
    marginTop: '0.5rem',
  },
};
