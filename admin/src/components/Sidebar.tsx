'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { clearAuth } from '@/lib/auth';
import { Home, LifeBuoy, Calendar, Users, IdCard, BookOpen, Trophy, LogOut } from 'lucide-react';

const NAV = [
  { href: '/dashboard',         label: 'Home',              icon: Home },
  { href: '/dashboard/issues',  label: 'Triage',            icon: LifeBuoy },
  { href: '/dashboard/events',  label: 'Community Events',  icon: Calendar },
  { href: '/dashboard/members',    label: 'Member Directory',  icon: Users },
  { href: '/dashboard/membership', label: 'Membership Cards',  icon: IdCard },
  { href: '/dashboard/directory',  label: 'Public Directory',  icon: BookOpen },
  { href: '/dashboard/sports',     label: 'Tournaments',       icon: Trophy },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  function logout() {
    clearAuth();
    router.push('/login');
  }

  return (
    <aside className="w-64 min-h-screen bg-primary-900 text-white flex flex-col shadow-xl z-20">
      <div className="p-6 border-b border-primary-800 flex items-center gap-4">
        <img
          src="/fyc_logo.png"
          alt="FYC"
          className="h-10 w-10 rounded-xl object-cover object-center flex-shrink-0 bg-white/10 p-1"
        />
        <div>
          <div className="text-lg font-bold leading-tight tracking-wide">Community OS</div>
          <div className="text-xs text-primary-200 font-medium tracking-wider uppercase mt-1">Admin Portal</div>
        </div>
      </div>

      <nav className="flex-1 p-4 space-y-1">
        {NAV.map(({ href, label, icon: Icon }) => {
          const active = pathname === href || (href !== '/dashboard' && pathname.startsWith(href));
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-semibold transition-all duration-200 ${
                active
                  ? 'bg-primary-600 text-white shadow-inner'
                  : 'text-primary-100 hover:bg-white/10 hover:text-white'
              }`}
            >
              <Icon className={`w-5 h-5 ${active ? 'opacity-100' : 'opacity-70'}`} />
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-primary-800 mt-auto">
        <button
          onClick={logout}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-semibold text-primary-100 hover:bg-white/10 hover:text-white transition-all duration-200"
        >
          <LogOut className="w-5 h-5 opacity-70" /> Logout
        </button>
      </div>
    </aside>
  );
}
