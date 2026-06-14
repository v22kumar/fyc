'use client';
import { FormEvent, useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Event } from '@/types';

export default function EventsPage() {
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    title_ta: '', title_en: '',
    description_ta: '', description_en: '',
    event_start: '', event_end: '',
  });
  const [error, setError] = useState('');

  async function load() {
    try {
      setEvents(await api.listEvents());
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function handleCreate(e: FormEvent) {
    e.preventDefault();
    setError('');
    setCreating(true);
    try {
      await api.createEvent({
        ...form,
        event_start: new Date(form.event_start).toISOString(),
        event_end: new Date(form.event_end).toISOString(),
      });
      setShowForm(false);
      setForm({ title_ta: '', title_en: '', description_ta: '', description_en: '', event_start: '', event_end: '' });
      await load();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create event');
    } finally {
      setCreating(false);
    }
  }

  const upcoming = events.filter((e) => new Date(e.event_start) > new Date());
  const past     = events.filter((e) => new Date(e.event_start) <= new Date());

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Events</h1>
          <p className="text-sm text-gray-500 mt-1">Create and manage FYC events</p>
        </div>
        <button
          onClick={() => setShowForm((p) => !p)}
          className="px-4 py-2 bg-primary-900 text-white text-sm font-semibold rounded-lg hover:bg-primary-800 transition-colors"
        >
          + New Event
        </button>
      </div>

      {/* Create Form */}
      {showForm && (
        <form onSubmit={handleCreate} className="bg-white rounded-card border border-gray-100 shadow-sm p-6 mb-6 space-y-4">
          <h2 className="font-semibold text-gray-800 mb-2">Create Event</h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Title (Tamil)</label>
              <input className="input" value={form.title_ta} onChange={(e) => setForm({ ...form, title_ta: e.target.value })} required />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Title (English)</label>
              <input className="input" value={form.title_en} onChange={(e) => setForm({ ...form, title_en: e.target.value })} required />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Description (Tamil)</label>
              <textarea className="input" rows={2} value={form.description_ta} onChange={(e) => setForm({ ...form, description_ta: e.target.value })} required />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Description (English)</label>
              <textarea className="input" rows={2} value={form.description_en} onChange={(e) => setForm({ ...form, description_en: e.target.value })} required />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Start</label>
              <input type="datetime-local" className="input" value={form.event_start} onChange={(e) => setForm({ ...form, event_start: e.target.value })} required />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">End</label>
              <input type="datetime-local" className="input" value={form.event_end} onChange={(e) => setForm({ ...form, event_end: e.target.value })} required />
            </div>
          </div>
          {error && <p className="text-sm text-accent">{error}</p>}
          <div className="flex gap-3">
            <button type="submit" disabled={creating} className="px-5 py-2 bg-primary-900 text-white text-sm font-semibold rounded-lg disabled:opacity-50">
              {creating ? 'Creating…' : 'Create'}
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="px-5 py-2 border border-gray-200 text-sm font-medium rounded-lg hover:bg-gray-50">
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="flex items-center justify-center h-40">
          <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          {upcoming.length > 0 && (
            <Section title="Upcoming" events={upcoming} />
          )}
          {past.length > 0 && (
            <Section title="Past" events={past} />
          )}
          {events.length === 0 && (
            <p className="text-center text-gray-400 py-16">No events yet. Create one above.</p>
          )}
        </>
      )}
    </div>
  );
}

function Section({ title, events }: { title: string; events: Event[] }) {
  return (
    <div className="mb-6">
      <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">{title}</h2>
      <div className="grid gap-4 md:grid-cols-2">
        {events.map((e) => (
          <div key={e.id} className="bg-white rounded-card border border-gray-100 shadow-sm p-5">
            <h3 className="font-semibold text-gray-800">{e.title_en}</h3>
            <p className="text-sm text-gray-500 mt-0.5">{e.title_ta}</p>
            <p className="text-xs text-gray-400 mt-2">
              {new Date(e.event_start).toLocaleString()} → {new Date(e.event_end).toLocaleString()}
            </p>
            <p className="text-sm text-gray-600 mt-2 line-clamp-2">{e.description_en}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
