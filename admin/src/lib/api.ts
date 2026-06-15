import { getToken } from './auth';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? 'http://localhost:8000';
const ORG_ID = process.env.NEXT_PUBLIC_DEFAULT_ORG_ID ?? '8f8b80b7-4b71-4770-b183-5c5f49e49a1d';

function headers(extra?: Record<string, string>): HeadersInit {
  const token = getToken();
  return {
    'Content-Type': 'application/json',
    'X-Organization-ID': ORG_ID,
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...extra,
  };
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: { ...headers(), ...(init?.headers ?? {}) },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(body.detail ?? 'Request failed');
  }
  return res.json() as Promise<T>;
}

export const api = {
  // Auth
  loginPassword: (orgId: string, username: string, password: string) =>
    request<{ access_token: string; user: object }>('/api/v1/auth/login/password', {
      method: 'POST',
      body: JSON.stringify({ organization_id: orgId, username, password }),
    }),

  // Issues
  listIssues: (status?: string) =>
    request<import('@/types').Issue[]>(
      `/api/v1/issues${status ? `?issue_status=${status}` : ''}`,
    ),
  updateIssueStatus: (
    id: string,
    status: string,
    assignedVolunteerId?: string,
    verificationPhotoUrl?: string,
  ) =>
    request<import('@/types').Issue>(`/api/v1/issues/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({
        status,
        ...(assignedVolunteerId ? { assigned_volunteer_id: assignedVolunteerId } : {}),
        ...(verificationPhotoUrl ? { verification_photo_url: verificationPhotoUrl } : {}),
      }),
    }),

  // Events
  listEvents: () => request<import('@/types').Event[]>('/api/v1/events'),
  createEvent: (payload: {
    title_ta: string;
    title_en: string;
    description_ta: string;
    description_en: string;
    event_start: string;
    event_end: string;
  }) =>
    request<import('@/types').Event>('/api/v1/events', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  // Members
  listMembers: (role?: string) =>
    request<import('@/types').Member[]>(
      `/api/v1/users${role ? `?role=${role}` : ''}`,
    ),

  // Membership
  listMembershipCards: () =>
    request<import('@/types').MembershipCard[]>('/api/v1/membership/list'),
  generateMembershipCard: (
    userId: string,
    designationTa: string,
    designationEn: string,
    expiresAt: string,
  ) =>
    request<import('@/types').MembershipCard>('/api/v1/membership/generate', {
      method: 'POST',
      body: JSON.stringify({
        user_id: userId,
        designation_ta: designationTa,
        designation_en: designationEn,
        expires_at: expiresAt,
      }),
    }),

  // Community Directory
  listCommunityProfiles: () => request('/api/v1/community?available_only=false'),
  verifyCommunityProfile: (id: string) => request(`/api/v1/community/${id}/verify`, { method: 'PATCH', body: JSON.stringify({}) }),
  deleteCommunityProfile: (id: string) => request(`/api/v1/community/${id}`, { method: 'DELETE' }),

  // Sports Hub
  listTournaments: () => request('/api/v1/sports/tournaments'),
  createTournament: (data: object) => request('/api/v1/sports/tournaments', { method: 'POST', body: JSON.stringify(data) }),
  listTeams: (tournamentId: string) => request(`/api/v1/sports/tournaments/${tournamentId}/teams`),
  createTeam: (tournamentId: string, data: object) => request(`/api/v1/sports/tournaments/${tournamentId}/teams`, { method: 'POST', body: JSON.stringify(data) }),
  listFixtures: (tournamentId: string) => request(`/api/v1/sports/tournaments/${tournamentId}/fixtures`),
  submitFixtureResult: (tournamentId: string, fixtureId: string, data: object) =>
    request(`/api/v1/sports/tournaments/${tournamentId}/fixtures/${fixtureId}/result`, { method: 'POST', body: JSON.stringify(data) }),
  listChallenges: () => request('/api/v1/sports/challenges'),
  respondChallenge: (id: string, data: object) => request(`/api/v1/sports/challenges/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),

  // Media
  uploadMedia: async (file: File): Promise<{ url: string }> => {
    const token = getToken();
    const form = new FormData();
    form.append('file', file);
    const res = await fetch(`${API_BASE}/api/v1/media/upload`, {
      method: 'POST',
      headers: {
        'X-Organization-ID': ORG_ID,
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: form,
    });
    if (!res.ok) throw new Error('Upload failed');
    return res.json();
  },
};
