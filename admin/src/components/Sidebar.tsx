'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { clearAuth } from '@/lib/auth';

const NAV = [
  { href: '/dashboard',         label: 'Dashboard',  icon: '📊' },
  { href: '/dashboard/issues',  label: 'Issues',     icon: '🚧' },
  { href: '/dashboard/events',  label: 'Events',     icon: '🎗️' },
  { href: '/dashboard/members',    label: 'Members',    icon: '👥' },
  { href: '/dashboard/membership', label: 'Membership', icon: '🪪' },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  function logout() {
    clearAuth();
    router.push('/login');
  }

  return (
    <aside className="w-56 min-h-screen bg-primary-900 text-white flex flex-col">
      <div className="p-5 border-b border-primary-800 flex items-center gap-3">
        <img
          src="/fyc_logo.png"
          alt="FYC"
          className="h-10 w-10 rounded-lg object-cover object-center flex-shrink-0"
        />
        <div>
          <div className="text-lg font-bold leading-tight">FYC Admin</div>
          <div className="text-xs text-primary-100">Nagercoil</div>
        </div>
      </div>

      <nav className="flex-1 p-4 space-y-1">
        {NAV.map(({ href, label, icon }) => {
          const active = pathname === href || (href !== '/dashboard' && pathname.startsWith(href));
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                active
                  ? 'bg-white/20 text-white'
                  : 'text-primary-100 hover:bg-white/10 hover:text-white'
              }`}
            >
              <span>{icon}</span>
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-primary-800">
        <button
          onClick={logout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-primary-100 hover:bg-white/10 hover:text-white transition-colors"
        >
          <span>🚪</span> Logout
        </button>
      </div>
    </aside>
  );
}
