'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { CommunityProfile } from '@/types';

const CATEGORY_LABELS: Record<string, string> = {
  carpenter: 'Carpenter', electrician: 'Electrician', plumber: 'Plumber',
  mason: 'Mason', painter: 'Painter', mechanic: 'Mechanic',
  ac_technician: 'AC Technician', mobile_repair: 'Mobile Repair', welder: 'Welder',
  tailor: 'Tailor', tutor: 'Tutor', doctor: 'Doctor', nurse: 'Nurse',
  lawyer: 'Lawyer', accountant: 'Accountant', photographer: 'Photographer',
  driver: 'Driver', caterer: 'Caterer', event_organizer: 'Event Organizer',
  grocery: 'Grocery', hardware: 'Hardware', pharmacy: 'Pharmacy',
  printing: 'Printing', computer_service: 'Computer Service', other: 'Other',
};

export default function DirectoryPage() {
  const [profiles, setProfiles] = useState<CommunityProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('');

  async function load() {
    setLoading(true);
    try {
      const data = await api.listCommunityProfiles();
      setProfiles(data);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function toggleVerify(id: string, current: boolean) {
    await api.verifyCommunityProfile(id);
    setProfiles(prev => prev.map(p => p.id === id ? { ...p, is_verified: !current } : p));
  }

  async function deleteProfile(id: string) {
    if (!confirm('Delete this profile?')) return;
    await api.deleteCommunityProfile(id);
    setProfiles(prev => prev.filter(p => p.id !== id));
  }

  const filtered = profiles.filter(p =>
    filter === '' ||
    (p.business_name_en ?? p.full_name_en ?? '').toLowerCase().includes(filter.toLowerCase()) ||
    p.category.includes(filter.toLowerCase())
  );

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Community Directory</h1>
          <p className="text-sm text-gray-500 mt-1">{profiles.length} registered profiles</p>
        </div>
        <input
          type="text"
          placeholder="Search name or category..."
          value={filter}
          onChange={e => setFilter(e.target.value)}
          className="w-64 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
        />
      </div>

      {loading ? (
        <div className="text-center py-12 text-gray-400">Loading...</div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-12 text-gray-400">No profiles found.</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(p => (
            <div key={p.id} className="bg-white rounded-xl border border-gray-200 p-4 shadow-sm">
              <div className="flex items-start justify-between mb-2">
                <div>
                  <div className="font-semibold text-gray-900">
                    {p.business_name_en || p.full_name_en || '—'}
                  </div>
                  {p.business_name_ta && (
                    <div className="text-sm text-gray-500">{p.business_name_ta}</div>
                  )}
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${p.is_verified ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                  {p.is_verified ? 'Verified' : 'Unverified'}
                </span>
              </div>

              <div className="flex items-center gap-2 mb-3">
                <span className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full font-medium">
                  {CATEGORY_LABELS[p.category] ?? p.category}
                </span>
                {p.is_available ? (
                  <span className="text-xs text-green-600">● Available</span>
                ) : (
                  <span className="text-xs text-gray-400">● Unavailable</span>
                )}
              </div>

              {p.description_en && (
                <p className="text-xs text-gray-500 mb-2 line-clamp-2">{p.description_en}</p>
              )}

              <div className="text-xs text-gray-400 space-y-0.5 mb-3">
                {p.service_area && <div>📍 {p.service_area}</div>}
                {p.contact_phone && <div>📞 {p.contact_phone}</div>}
                {p.years_experience && <div>⏱ {p.years_experience} yrs experience</div>}
              </div>

              <div className="flex gap-2 pt-2 border-t border-gray-100">
                <button
                  onClick={() => toggleVerify(p.id, p.is_verified)}
                  className={`flex-1 text-xs py-1.5 rounded-lg font-medium transition-colors ${
                    p.is_verified
                      ? 'bg-yellow-50 text-yellow-700 hover:bg-yellow-100'
                      : 'bg-green-50 text-green-700 hover:bg-green-100'
                  }`}
                >
                  {p.is_verified ? 'Unverify' : 'Verify'}
                </button>
                <button
                  onClick={() => deleteProfile(p.id)}
                  className="flex-1 text-xs py-1.5 rounded-lg font-medium bg-red-50 text-red-600 hover:bg-red-100 transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
