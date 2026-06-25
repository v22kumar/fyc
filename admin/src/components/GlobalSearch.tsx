'use client';
import { useState, useEffect, useRef } from 'react';
import { Search, Loader2, Users, Trophy, Calendar, Newspaper, LifeBuoy } from 'lucide-react';
import { api } from '@/lib/api';
import Link from 'next/link';

export default function GlobalSearch() {
  const [query, setQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState<any>(null);
  const wrapperRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    if (!query) {
      setResults(null);
      return;
    }
    
    const timeoutId = setTimeout(async () => {
      setLoading(true);
      try {
        const data = await api.globalSearch(query);
        setResults(data);
        setIsOpen(true);
      } catch (err) {
        console.error('Search failed', err);
      } finally {
        setLoading(false);
      }
    }, 300); // debounce

    return () => clearTimeout(timeoutId);
  }, [query]);

  const renderIcon = (type: string) => {
    switch (type) {
      case 'people': return <Users className="w-4 h-4 text-blue-500" />;
      case 'tournaments': return <Trophy className="w-4 h-4 text-yellow-500" />;
      case 'events': return <Calendar className="w-4 h-4 text-green-500" />;
      case 'news': return <Newspaper className="w-4 h-4 text-purple-500" />;
      case 'issues': return <LifeBuoy className="w-4 h-4 text-red-500" />;
      default: return <Search className="w-4 h-4 text-gray-500" />;
    }
  };

  const getHref = (type: string, id: string) => {
    switch (type) {
      case 'people': return `/dashboard/members`;
      case 'tournaments': return `/dashboard/sports`;
      case 'events': return `/dashboard/events`;
      case 'issues': return `/dashboard/issues`;
      default: return '#';
    }
  };

  return (
    <div ref={wrapperRef} className="relative w-full max-w-md">
      <div className="relative flex items-center">
        <Search className="absolute left-3 text-gray-400 w-5 h-5" />
        <input
          type="text"
          placeholder="Search People, Tournaments, Events, Issues..."
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            if (e.target.value) setIsOpen(true);
          }}
          onFocus={() => { if (query) setIsOpen(true); }}
          className="w-full pl-10 pr-4 py-2 bg-white border border-gray-200 rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 shadow-sm transition-all"
        />
        {loading && <Loader2 className="absolute right-3 w-4 h-4 text-gray-400 animate-spin" />}
      </div>

      {isOpen && results && (
        <div className="absolute top-full mt-2 w-full max-w-2xl bg-white rounded-xl shadow-xl border border-gray-100 overflow-hidden z-50 p-2">
          {Object.keys(results).length === 0 || Object.values(results).every((arr: any) => arr.length === 0) ? (
            <div className="p-4 text-sm text-gray-500 text-center">No results found for "{query}"</div>
          ) : (
            <div className="max-h-96 overflow-y-auto custom-scrollbar">
              {Object.entries(results).map(([category, items]: [string, any]) => {
                if (!items || items.length === 0) return null;
                return (
                  <div key={category} className="mb-4 last:mb-0">
                    <h3 className="px-3 text-xs font-bold text-gray-400 uppercase tracking-wider mb-2 flex items-center gap-2">
                      {renderIcon(category)} {category}
                    </h3>
                    <ul className="space-y-1">
                      {items.map((item: any) => (
                        <li key={item.id}>
                          <Link href={getHref(category, item.id)} className="block px-3 py-2 rounded-lg hover:bg-gray-50 transition-colors">
                            <div className="text-sm font-medium text-gray-800">{item.title || item.name || item.title_en}</div>
                            <div className="text-xs text-gray-500 mt-0.5 line-clamp-1">{item.description || item.description_en || item.subtitle}</div>
                          </Link>
                        </li>
                      ))}
                    </ul>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
