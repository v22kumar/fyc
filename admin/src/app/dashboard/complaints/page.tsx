'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Megaphone, Save } from 'lucide-react';
import toast from 'react-hot-toast';

type Dept = {
  id: string;
  category: string;
  name_en: string;
  name_ta?: string | null;
  email?: string | null;
  cc_emails?: string | null;
  phone?: string | null;
  helpline?: string | null;
  portal_url?: string | null;
  is_active: boolean;
};

const FIELDS: { key: keyof Dept; label: string; placeholder: string }[] = [
  { key: 'email', label: 'Officer email', placeholder: 'officer@dept.tn.gov.in' },
  { key: 'cc_emails', label: 'CC (comma-sep)', placeholder: 'cc1@…, cc2@…' },
  { key: 'phone', label: 'Phone', placeholder: '' },
  { key: 'helpline', label: 'Helpline', placeholder: '1100' },
  { key: 'portal_url', label: 'Portal URL', placeholder: 'https://…' },
];

export default function ComplaintsPage() {
  const [rows, setRows] = useState<Dept[]>([]);
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    try {
      setRows(await api.listComplaintDepartments());
    } catch (e: any) {
      toast.error(e.message ?? 'Failed to load departments');
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => { load(); }, []);

  function edit(id: string, key: keyof Dept, value: any) {
    setRows((rs) => rs.map((r) => (r.id === id ? { ...r, [key]: value } : r)));
  }

  async function save(row: Dept) {
    setSavingId(row.id);
    try {
      await api.patchComplaintDepartment(row.id, {
        name_en: row.name_en,
        email: row.email || null,
        cc_emails: row.cc_emails || null,
        phone: row.phone || null,
        helpline: row.helpline || null,
        portal_url: row.portal_url || null,
        is_active: row.is_active,
      });
      toast.success(`${row.name_en} saved`);
    } catch (e: any) {
      toast.error(e.message ?? 'Save failed');
    } finally {
      setSavingId(null);
    }
  }

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex items-center gap-3 mb-2">
        <Megaphone className="text-orange-600" />
        <h1 className="text-2xl font-bold text-gray-900">Complaint Routing</h1>
      </div>
      <p className="text-sm text-gray-500 mb-6">
        Set the concerned officer email for each category so citizen complaints are dispatched
        automatically (with an AI-drafted letter, the GPS address and photo). Rows without an email
        fall back to the public helpline / portal shown to the citizen.
      </p>

      {loading ? (
        <p className="text-gray-500">Loading…</p>
      ) : (
        <div className="space-y-4">
          {rows.map((r) => (
            <div key={r.id} className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
              <div className="flex items-center justify-between mb-3">
                <div>
                  <span className="text-[11px] font-bold text-orange-600 uppercase tracking-wide">{r.category}</span>
                  <div className="font-semibold text-gray-900">{r.name_en}</div>
                </div>
                <label className="flex items-center gap-2 text-xs text-gray-600">
                  <input type="checkbox" checked={r.is_active}
                    onChange={(e) => edit(r.id, 'is_active', e.target.checked)} />
                  Active
                </label>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {FIELDS.map((f) => (
                  <div key={f.key as string}>
                    <label className="block text-[11px] font-bold text-gray-500 mb-1">{f.label}</label>
                    <input
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
                      value={(r[f.key] as string) ?? ''}
                      placeholder={f.placeholder}
                      onChange={(e) => edit(r.id, f.key, e.target.value)}
                    />
                  </div>
                ))}
              </div>
              <div className="flex justify-end mt-3">
                <button
                  onClick={() => save(r)}
                  disabled={savingId === r.id}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-orange-600 text-white text-sm font-bold disabled:opacity-60">
                  <Save className="w-4 h-4" /> {savingId === r.id ? 'Saving…' : 'Save'}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
