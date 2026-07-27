'use client';
import { FormEvent, useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { Event } from '@/types';
import { ShareLinkBadge } from '@/components/ShareLinkBadge';
import toast from 'react-hot-toast';
import { CalendarX, Loader2, Pencil, Trash2 } from 'lucide-react';

export default function EventsPage() {
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [isAdvanced, setIsAdvanced] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const emptyForm = {
    title_ta: '', title_en: '',
    description_ta: '', description_en: '',
    event_start: '', event_end: '',
    requires_registration: true,
  };
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState('');

  // datetime-local wants "YYYY-MM-DDTHH:mm" in local time, not an ISO string.
  function toLocalInput(iso: string): string {
    const d = new Date(iso);
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function startEdit(ev: Event) {
    setEditingId(ev.id);
    setIsAdvanced(true);
    setForm({
      title_ta: ev.title_ta || '',
      title_en: ev.title_en || '',
      description_ta: ev.description_ta || '',
      description_en: ev.description_en || '',
      event_start: ev.event_start ? toLocalInput(ev.event_start) : '',
      event_end: ev.event_end ? toLocalInput(ev.event_end) : '',
      requires_registration: ev.registration_enabled ?? ev.requires_registration ?? true,
    });
    setShowForm(true);
    if (typeof window !== 'undefined') window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function cancelForm() {
    setShowForm(false);
    setEditingId(null);
    setForm(emptyForm);
    setError('');
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this event? This cannot be undone.')) return;
    try {
      await api.deleteEvent(id);
      toast.success('Event deleted');
      setEvents((prev) => prev.filter((e) => e.id !== id));
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to delete event');
    }
  }

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

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setCreating(true);
    try {
      if (editingId) {
        await api.updateEvent(editingId, {
          title_ta: form.title_ta,
          title_en: form.title_en,
          description_ta: form.description_ta,
          description_en: form.description_en,
          event_start: new Date(form.event_start).toISOString(),
          event_end: new Date(form.event_end).toISOString(),
          registration_enabled: form.requires_registration,
        });
        toast.success('Event updated');
      } else {
        await api.createEvent({
          ...form,
          event_start: new Date(form.event_start).toISOString(),
          event_end: new Date(form.event_end).toISOString(),
        });
        toast.success('Event created successfully!');
      }
      cancelForm();
      await load();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : `Failed to ${editingId ? 'update' : 'create'} event`;
      toast.error(msg);
      setError(msg);
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
          onClick={() => { if (showForm) { cancelForm(); } else { setForm(emptyForm); setEditingId(null); setShowForm(true); } }}
          className="px-4 py-2 bg-primary-900 text-white text-sm font-semibold rounded-lg hover:bg-primary-800 transition-colors"
        >
          + New Event
        </button>
      </div>

      {/* Create Form */}
      {showForm && (
        <form onSubmit={handleSubmit} className="bg-white rounded-card border border-gray-100 shadow-sm p-6 mb-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-gray-800">{editingId ? 'Edit Event' : 'Create Event'}</h2>
            <div className="flex items-center gap-2">
              <span className="text-xs font-medium text-gray-500">Advanced Mode</span>
              <button
                type="button"
                onClick={() => setIsAdvanced(!isAdvanced)}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${isAdvanced ? 'bg-primary-600' : 'bg-gray-200'}`}
              >
                <span className={`inline-block h-3 w-3 transform rounded-full bg-white transition-transform ${isAdvanced ? 'translate-x-5' : 'translate-x-1'}`} />
              </button>
            </div>
          </div>
          
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className={!isAdvanced ? "col-span-1 md:col-span-2" : ""}>
                <label className="block text-xs font-medium text-gray-500 mb-1">Event Title</label>
                <input className="input" placeholder="E.g. Beach Cleanup Drive" value={form.title_en} onChange={(e) => setForm({ ...form, title_en: e.target.value, title_ta: !isAdvanced ? e.target.value : form.title_ta })} required />
              </div>
              {isAdvanced && (
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Title (Tamil)</label>
                  <input className="input" placeholder="நிகழ்வு தலைப்பு" value={form.title_ta} onChange={(e) => setForm({ ...form, title_ta: e.target.value })} required={isAdvanced} />
                </div>
              )}
              
              <div className={!isAdvanced ? "col-span-1 md:col-span-2" : ""}>
                <label className="block text-xs font-medium text-gray-500 mb-1">Description</label>
                <textarea className="input" rows={!isAdvanced ? 3 : 2} placeholder="Briefly describe the event..." value={form.description_en} onChange={(e) => setForm({ ...form, description_en: e.target.value, description_ta: !isAdvanced ? e.target.value : form.description_ta })} required />
              </div>
              {isAdvanced && (
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Description (Tamil)</label>
                  <textarea className="input" rows={2} placeholder="விளக்கம்..." value={form.description_ta} onChange={(e) => setForm({ ...form, description_ta: e.target.value })} required={isAdvanced} />
                </div>
              )}
              
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Start Date & Time</label>
                <input type="datetime-local" className="input" value={form.event_start} onChange={(e) => setForm({ ...form, event_start: e.target.value })} required />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">End Date & Time</label>
                <input type="datetime-local" className="input" value={form.event_end} onChange={(e) => setForm({ ...form, event_end: e.target.value })} required />
              </div>
              
              {isAdvanced && (
                <div className="col-span-1 md:col-span-2 flex items-center mt-2 p-3 bg-gray-50 rounded-lg border border-gray-100">
                  <input
                    type="checkbox"
                    id="requires_registration"
                    checked={form.requires_registration}
                    onChange={(e) => setForm({ ...form, requires_registration: e.target.checked })}
                    className="w-4 h-4 text-primary-600 bg-white border-gray-300 rounded focus:ring-primary-500"
                  />
                  <label htmlFor="requires_registration" className="ml-3 text-sm font-medium text-gray-700">
                    Require attendees to register before the event
                  </label>
                </div>
              )}
            </div>
          </div>
          {error && <p className="text-sm text-accent mt-4">{error}</p>}
          <div className="flex gap-3 mt-6 pt-4 border-t border-gray-100">
            <button type="submit" disabled={creating} className="px-5 py-2.5 bg-primary-900 text-white text-sm font-semibold rounded-lg disabled:opacity-70 disabled:cursor-not-allowed hover:bg-primary-800 transition-colors shadow-sm flex items-center justify-center gap-2">
              {creating && <Loader2 className="w-4 h-4 animate-spin" />}
              {creating ? (editingId ? 'Saving...' : 'Creating Event...') : (editingId ? 'Save Changes' : 'Create Event')}
            </button>
            <button type="button" onClick={cancelForm} className="px-5 py-2.5 border border-gray-200 text-sm font-medium rounded-lg hover:bg-gray-50 transition-colors">
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="grid gap-4 md:grid-cols-2">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="bg-white rounded-card border border-gray-100 shadow-sm p-5 animate-pulse">
              <div className="h-5 bg-gray-200 rounded w-1/2 mb-2"></div>
              <div className="h-4 bg-gray-100 rounded w-1/3 mb-4"></div>
              <div className="h-3 bg-gray-100 rounded w-1/4 mb-3"></div>
              <div className="h-3 bg-gray-100 rounded w-full mb-1"></div>
              <div className="h-3 bg-gray-100 rounded w-2/3"></div>
            </div>
          ))}
        </div>
      ) : (
        <>
          {upcoming.length > 0 && (
            <Section title="Upcoming" events={upcoming} onEdit={startEdit} onDelete={handleDelete} />
          )}
          {past.length > 0 && (
            <Section title="Past" events={past} onEdit={startEdit} onDelete={handleDelete} />
          )}
          {events.length === 0 && (
            <div className="flex flex-col items-center justify-center py-20 px-4 text-center bg-white rounded-xl border border-gray-100 shadow-sm border-dashed">
              <div className="w-16 h-16 bg-gray-50 rounded-full flex items-center justify-center mb-4">
                <CalendarX className="w-8 h-8 text-gray-400" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 mb-1">No events scheduled</h3>
              <p className="text-sm text-gray-500 max-w-sm mb-6">There are no upcoming or past events in the system. Create a new event to get started.</p>
              <button onClick={() => setShowForm(true)} className="px-5 py-2 bg-primary-900 text-white text-sm font-medium rounded-lg hover:bg-primary-800 transition-colors shadow-sm">
                Create First Event
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function Section({
  title,
  events,
  onEdit,
  onDelete,
}: {
  title: string;
  events: Event[];
  onEdit: (e: Event) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <div className="mb-6">
      <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">{title}</h2>
      <div className="grid gap-4 md:grid-cols-2">
        {events.map((e) => (
          <div key={e.id} className="bg-white rounded-card border border-gray-100 shadow-sm p-5">
            <div className="flex justify-between items-start gap-2">
              <div className="min-w-0">
                <h3 className="font-semibold text-gray-800">{e.title_en}</h3>
                <p className="text-sm text-gray-500 mt-0.5">{e.title_ta}</p>
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  onClick={() => onEdit(e)}
                  title="Edit event"
                  className="p-1.5 rounded-md text-gray-500 hover:bg-gray-100 hover:text-primary-700 transition-colors"
                >
                  <Pencil className="w-4 h-4" />
                </button>
                <button
                  type="button"
                  onClick={() => onDelete(e.id)}
                  title="Delete event"
                  className="p-1.5 rounded-md text-gray-500 hover:bg-red-50 hover:text-red-600 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
            <p className="text-xs text-gray-400 mt-2">
              {new Date(e.event_start).toLocaleString()} → {new Date(e.event_end).toLocaleString()}
            </p>
            <p className="text-sm text-gray-600 mt-2 line-clamp-2">{e.description_en}</p>
            <ShareLinkBadge kind="e" code={e.short_code} />
          </div>
        ))}
      </div>
    </div>
  );
}
