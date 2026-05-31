'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';
import SchoolSelector from '@/components/SchoolSelector';
import {
  LayoutDashboard,
  Users,
  ClipboardCheck,
  Banknote,
  ArrowLeftRight,
  Store,
  BarChart3,
  Megaphone,
  MessageCircle,
  Settings,
  LogOut,
  School,
  GraduationCap,
  BookOpen,
  FileText,
} from 'lucide-react';

const adminNavigation = [
  { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { name: 'Students', href: '/dashboard/students', icon: Users },
  { name: 'Attendance', href: '/dashboard/attendance', icon: ClipboardCheck },
  { name: 'Grades', href: '/dashboard/grades', icon: BookOpen },
  { name: 'Report Cards', href: '/dashboard/report-cards', icon: FileText },
  { name: 'Teachers', href: '/dashboard/teachers', icon: GraduationCap },
  { name: 'Deposits', href: '/dashboard/deposits', icon: Banknote },
  { name: 'Transactions', href: '/dashboard/transactions', icon: ArrowLeftRight },
  { name: 'Sellers', href: '/dashboard/sellers', icon: Store },
  { name: 'Reports', href: '/dashboard/reports', icon: BarChart3 },
  { name: 'Announcements', href: '/dashboard/announcements', icon: Megaphone },
  { name: 'Messages', href: '/dashboard/chat', icon: MessageCircle },
];

const teacherNavigation = [
  { name: 'Attendance', href: '/dashboard/attendance', icon: ClipboardCheck },
  { name: 'Grades', href: '/dashboard/grades', icon: BookOpen },
  { name: 'Report Cards', href: '/dashboard/report-cards', icon: FileText },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { userRole } = useSchoolContext();

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.push('/');
  }

  return (
    <aside className="fixed inset-y-0 left-0 z-10 flex w-64 flex-col border-r border-gray-200 bg-white">
      {/* Logo */}
      <div className="flex h-16 items-center gap-3 border-b border-gray-200 px-6">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-blue-600">
          <Banknote className="h-5 w-5 text-white" />
        </div>
        <div>
          <h1 className="text-lg font-bold text-gray-900">Paynow MM</h1>
          <p className="text-[10px] font-medium text-gray-400 uppercase tracking-wider">Admin Panel</p>
        </div>
      </div>

      {/* School Selector */}
      <SchoolSelector />

      {/* Navigation */}
      <nav className="flex-1 space-y-1 px-3 py-4 overflow-y-auto">
        {(userRole === 'teacher' ? teacherNavigation : adminNavigation).map((item) => {
          const isActive = pathname === item.href ||
            (item.href !== '/dashboard' && pathname.startsWith(item.href));
          return (
            <Link
              key={item.name}
              href={item.href}
              className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-blue-50 text-blue-700'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              }`}
            >
              <item.icon className={`h-5 w-5 ${isActive ? 'text-blue-700' : 'text-gray-400'}`} />
              {item.name}
            </Link>
          );
        })}

        {/* Schools nav item - only for super_admin */}
        {userRole === 'super_admin' && (
          <Link
            href="/dashboard/schools"
            className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              pathname === '/dashboard/schools' || pathname.startsWith('/dashboard/schools/')
                ? 'bg-blue-50 text-blue-700'
                : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
            }`}
          >
            <School className={`h-5 w-5 ${
              pathname === '/dashboard/schools' || pathname.startsWith('/dashboard/schools/')
                ? 'text-blue-700' : 'text-gray-400'
            }`} />
            Schools
          </Link>
        )}
      </nav>

      {/* Footer */}
      <div className="border-t border-gray-200 p-3">
        {userRole !== 'teacher' && (
          <Link
            href="/dashboard/settings"
            className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
          >
            <Settings className="h-5 w-5 text-gray-400" />
            Settings
          </Link>
        )}
        <button
          onClick={handleSignOut}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
        >
          <LogOut className="h-5 w-5 text-gray-400" />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
