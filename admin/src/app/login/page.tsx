'use client';
import { FormEvent, useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import { saveAuth } from '@/lib/auth';

const DEFAULT_ORG = process.env.NEXT_PUBLIC_DEFAULT_ORG_ID ?? '8f8b80b7-4b71-4770-b183-5c5f49e49a1d';

function LoginContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [orgId, setOrgId] = useState(DEFAULT_ORG);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const isExpired = searchParams?.get('expired') === 'true';

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await api.loginPassword(orgId, username, password);
      saveAuth(data.access_token, data.user);
      router.push('/dashboard');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-primary-900 px-4">
      <div className="w-full max-w-md bg-white rounded-card shadow-2xl p-8">
        <div className="text-center mb-8">
          <img
            src="/fyc_logo.png"
            alt="FYC"
            className="h-24 w-24 mx-auto mb-3 rounded-2xl object-cover object-center shadow-lg"
          />
          <h1 className="text-2xl font-bold text-primary-900">FYC Admin Portal</h1>
          <p className="text-sm text-gray-500 mt-1">Friends Youth Club — Nagercoil</p>
        </div>

        {isExpired && (
          <div className="mb-6 p-4 bg-yellow-50 border border-yellow-200 text-yellow-800 rounded-lg text-sm font-medium text-center">
            Your session has expired. Please sign in again.
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Organization ID
            </label>
            <input
              type="text"
              value={orgId}
              onChange={(e) => setOrgId(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Phone / Email
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="+919876543210 or admin@fycconnect.org"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              required
            />
          </div>

          {error && (
            <p className="text-sm text-accent font-medium bg-accent-100 border border-accent px-3 py-2 rounded-lg">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-primary text-white font-semibold rounded-lg hover:bg-primary-800 transition-colors disabled:opacity-50"
          >
            {loading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-primary-900" />}>
      <LoginContent />
    </Suspense>
  );
}
