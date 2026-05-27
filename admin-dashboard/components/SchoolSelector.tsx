'use client';

import { useSchoolContext } from '@/lib/school-context';
import { School } from 'lucide-react';

export default function SchoolSelector() {
  const { selectedSchoolId, setSelectedSchool, userRole, schools, loading } = useSchoolContext();

  if (loading) {
    return (
      <div className="px-4 py-3">
        <div className="h-9 animate-pulse rounded-lg bg-gray-100" />
      </div>
    );
  }

  if (schools.length === 0) {
    return null;
  }

  // School admin: show their school name (read-only)
  if (userRole !== 'super_admin') {
    const currentSchool = schools.find(s => s.id === selectedSchoolId);
    return (
      <div className="px-4 py-3">
        <div className="flex items-center gap-2 rounded-lg bg-blue-50 px-3 py-2">
          <School className="h-4 w-4 text-blue-600 shrink-0" />
          <span className="text-sm font-medium text-blue-900 truncate">
            {currentSchool?.name || 'Unknown School'}
          </span>
        </div>
      </div>
    );
  }

  // Super admin: dropdown to select school
  return (
    <div className="px-4 py-3">
      <div className="relative">
        <School className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400 pointer-events-none" />
        <select
          value={selectedSchoolId || ''}
          onChange={(e) => setSelectedSchool(e.target.value || null)}
          className="w-full appearance-none rounded-lg border border-gray-200 bg-white py-2 pl-9 pr-8 text-sm font-medium text-gray-700 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option value="">All Schools</option>
          {schools.map((school) => (
            <option key={school.id} value={school.id}>
              {school.name}
            </option>
          ))}
        </select>
        <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
          <svg className="h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </div>
    </div>
  );
}
