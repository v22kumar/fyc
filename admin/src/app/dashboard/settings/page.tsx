'use client';
import { useState, useEffect } from 'react';
import { api } from '@/lib/api';
import { toast } from 'react-hot-toast';
import { Palette, Save, RefreshCw } from 'lucide-react';

export default function SettingsPage() {
  const [themeJson, setThemeJson] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadTheme();
  }, []);

  async function loadTheme() {
    setLoading(true);
    try {
      const data = await api.getTheme();
      // Format JSON with 2 spaces for readability
      setThemeJson(JSON.stringify(data, null, 2));
    } catch (err: any) {
      toast.error(err.message || 'Failed to load theme');
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    try {
      setSaving(true);
      // Validate JSON first
      const payload = JSON.parse(themeJson);
      
      await api.updateTheme(payload);
      toast.success('Theme updated successfully!');
      
      // Bump version automatically if they forgot? Better to just let them manage it,
      // but let's refresh to show what was saved.
      await loadTheme();
    } catch (err: any) {
      if (err instanceof SyntaxError) {
        toast.error('Invalid JSON format. Please check your syntax.');
      } else {
        toast.error(err.message || 'Failed to save theme');
      }
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Platform Settings</h1>
        <p className="text-gray-500 mt-1">Configure application-wide parameters and styling.</p>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="border-b border-gray-100 p-6 flex items-center justify-between bg-gray-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary-100 flex items-center justify-center text-primary-600">
              <Palette className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-gray-900">Semantic Theme Configuration</h2>
              <p className="text-sm text-gray-500">Edit the JSON below to remotely update the mobile app's colors.</p>
            </div>
          </div>
          <button
            onClick={loadTheme}
            disabled={loading || saving}
            className="p-2 text-gray-400 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            title="Reload Theme"
          >
            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>

        <div className="p-6">
          <div className="mb-4 flex items-center justify-between">
            <label className="block text-sm font-semibold text-gray-700">
              Theme JSON
            </label>
            <span className="text-xs font-medium px-2 py-1 bg-amber-100 text-amber-700 rounded-md">
              Requires valid JSON syntax
            </span>
          </div>
          
          <textarea
            value={themeJson}
            onChange={(e) => setThemeJson(e.target.value)}
            disabled={loading || saving}
            className="w-full h-[500px] font-mono text-sm p-4 bg-gray-900 text-gray-100 rounded-xl border-none focus:ring-2 focus:ring-primary-500 focus:outline-none resize-y"
            spellCheck={false}
            placeholder="Loading..."
          />

          <div className="mt-6 flex justify-end">
            <button
              onClick={handleSave}
              disabled={loading || saving}
              className="flex items-center gap-2 px-6 py-3 bg-primary-600 text-white font-semibold rounded-xl hover:bg-primary-700 disabled:opacity-50 transition-colors"
            >
              {saving ? (
                <RefreshCw className="w-5 h-5 animate-spin" />
              ) : (
                <Save className="w-5 h-5" />
              )}
              {saving ? 'Saving...' : 'Save Theme'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
