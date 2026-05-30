'use client';

import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';
import { supabase } from '@/lib/supabase';
import type { School } from '@/lib/types';

interface SchoolContextValue {
  selectedSchoolId: string | null;
  setSelectedSchool: (id: string | null) => void;
  userRole: 'admin' | 'super_admin' | 'teacher';
  userSchoolId: string | null;
  schools: School[];
  loading: boolean;
}

const SchoolContext = createContext<SchoolContextValue>({
  selectedSchoolId: null,
  setSelectedSchool: () => {},
  userRole: 'admin',
  userSchoolId: null,
  schools: [],
  loading: true,
});

export function useSchoolContext() {
  return useContext(SchoolContext);
}

const STORAGE_KEY = 'canteenpay_selected_school';

export function SchoolProvider({ children }: { children: ReactNode }) {
  const [selectedSchoolId, setSelectedSchoolIdState] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<'admin' | 'super_admin' | 'teacher'>('admin');
  const [userSchoolId, setUserSchoolId] = useState<string | null>(null);
  const [schools, setSchools] = useState<School[]>([]);
  const [loading, setLoading] = useState(true);

  const setSelectedSchool = useCallback((id: string | null) => {
    setSelectedSchoolIdState(id);
    if (id) {
      localStorage.setItem(STORAGE_KEY, id);
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  }, []);

  useEffect(() => {
    async function init() {
      try {
        // Get current user
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          setLoading(false);
          return;
        }

        // Fetch profile to get role and school_id
        const { data: profile } = await supabase
          .from('profiles')
          .select('role, school_id')
          .eq('id', user.id)
          .single();

        const role = profile?.role === 'super_admin' ? 'super_admin' : profile?.role === 'teacher' ? 'teacher' : 'admin';
        const profileSchoolId = profile?.school_id || null;

        setUserRole(role);
        setUserSchoolId(profileSchoolId);

        // Fetch schools list
        const { data: schoolsData } = await supabase
          .from('schools')
          .select('*')
          .order('name');

        setSchools(schoolsData || []);

        // Determine selected school
        if (role === 'super_admin') {
          // Super admin: restore from localStorage or default to null (all schools)
          const stored = localStorage.getItem(STORAGE_KEY);
          if (stored && (schoolsData || []).some((s: School) => s.id === stored)) {
            setSelectedSchoolIdState(stored);
          } else {
            setSelectedSchoolIdState(null);
          }
        } else {
          // School admin or teacher: always use their own school
          setSelectedSchoolIdState(profileSchoolId);
        }
      } catch (err) {
        console.error('Failed to initialize school context:', err);
      }
      setLoading(false);
    }

    init();
  }, []);

  return (
    <SchoolContext.Provider
      value={{
        selectedSchoolId,
        setSelectedSchool,
        userRole,
        userSchoolId,
        schools,
        loading,
      }}
    >
      {children}
    </SchoolContext.Provider>
  );
}
