'use client';

import { useState, useEffect, useCallback } from 'react';
import { Search, Plus, Download, Upload } from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';

interface StudentRow {
  id: string;
  student_code: string;
  full_name: string;
  class_name: string | null;
  grade: string | null;
  is_active: boolean;
  balance: number;
}

export default function StudentsPage() {
  const [students, setStudents] = useState<StudentRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [gradeFilter, setGradeFilter] = useState('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState('');

  // Form state for add student
  const [newName, setNewName] = useState('');
  const [newNameMy, setNewNameMy] = useState('');
  const [newGrade, setNewGrade] = useState('1');
  const [newSection, setNewSection] = useState('A');
  const [newPhone, setNewPhone] = useState('');

  const fetchStudents = useCallback(async () => {
    const { data, error } = await supabase
      .from('students')
      .select('id, student_code, full_name, class_name, grade, is_active, wallets(balance)')
      .order('full_name');

    if (error) {
      console.error('Error fetching students:', error);
      setLoading(false);
      return;
    }

    const mapped: StudentRow[] = (data || []).map((s: Record<string, unknown>) => {
      const wallets = s.wallets as Array<{ balance: number }> | { balance: number } | null;
      let balance = 0;
      if (Array.isArray(wallets) && wallets.length > 0) {
        balance = wallets[0].balance || 0;
      } else if (wallets && !Array.isArray(wallets)) {
        balance = wallets.balance || 0;
      }
      return {
        id: s.id as string,
        student_code: s.student_code as string,
        full_name: s.full_name as string,
        class_name: s.class_name as string | null,
        grade: s.grade as string | null,
        is_active: s.is_active as boolean,
        balance,
      };
    });

    setStudents(mapped);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchStudents();
  }, [fetchStudents]);

  const filtered = students.filter(s => {
    const matchesSearch = search === '' ||
      s.full_name.toLowerCase().includes(search.toLowerCase()) ||
      s.student_code.toLowerCase().includes(search.toLowerCase());
    const matchesGrade = gradeFilter === 'all' || s.grade === gradeFilter;
    return matchesSearch && matchesGrade;
  });

  const grades = [...new Set(students.map(s => s.grade).filter(Boolean))].sort() as string[];

  async function handleAddStudent() {
    setAddLoading(true);
    setAddError('');

    const className = `Grade ${newGrade}-${newSection}`;
    const studentCode = `STU-${new Date().getFullYear()}-${String(students.length + 1).padStart(3, '0')}`;

    // Get a school_id - try to find one or use a placeholder
    const { data: schools } = await supabase.from('schools').select('id').limit(1);
    const schoolId = schools?.[0]?.id;

    if (!schoolId) {
      setAddError('No school found. Please create a school first.');
      setAddLoading(false);
      return;
    }

    const { error } = await supabase.from('students').insert({
      full_name: newName,
      full_name_my: newNameMy || null,
      grade: newGrade,
      class_name: className,
      student_code: studentCode,
      qr_data: `QR-${studentCode}`,
      school_id: schoolId,
      is_active: true,
    });

    if (error) {
      setAddError(error.message);
      setAddLoading(false);
      return;
    }

    setShowAddModal(false);
    setNewName('');
    setNewNameMy('');
    setNewGrade('1');
    setNewSection('A');
    setNewPhone('');
    setAddLoading(false);
    fetchStudents();
  }

  if (loading) {
    return (
      <div>
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Students</h1>
            <p className="mt-1 text-sm text-gray-500">Loading...</p>
          </div>
        </div>
        <div className="space-y-2">
          {[1, 2, 3, 4, 5].map(i => (
            <div key={i} className="h-14 animate-pulse rounded-lg bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Students</h1>
          <p className="mt-1 text-sm text-gray-500">{students.length} registered students</p>
        </div>
        <div className="flex gap-2">
          <button className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
            <Upload className="h-4 w-4" /> CSV Import
          </button>
          <button className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
            <Download className="h-4 w-4" /> Export
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" /> Add Student
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="mb-4 flex gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search students..."
            className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-4 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <select
          value={gradeFilter}
          onChange={(e) => setGradeFilter(e.target.value)}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option value="all">All Grades</option>
          {grades.map(g => (
            <option key={g} value={g}>Grade {g}</option>
          ))}
        </select>
      </div>

      {/* Student Table */}
      <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Student</th>
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">ID</th>
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Class</th>
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Balance</th>
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-6 py-8 text-center text-sm text-gray-400">
                  {search || gradeFilter !== 'all' ? 'No students match your search' : 'No students yet'}
                </td>
              </tr>
            ) : (
              filtered.map((student) => (
                <tr key={student.id} className="hover:bg-gray-50">
                  <td className="whitespace-nowrap px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">
                        {student.full_name.charAt(0)}
                      </div>
                      <span className="text-sm font-medium text-gray-900">{student.full_name}</span>
                    </div>
                  </td>
                  <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 font-mono">{student.student_code}</td>
                  <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500">{student.class_name || '-'}</td>
                  <td className={`whitespace-nowrap px-6 py-4 text-sm font-medium ${
                    student.balance < 1000 ? 'text-red-600' : 'text-gray-900'
                  }`}>
                    {formatMMK(student.balance)}
                  </td>
                  <td className="whitespace-nowrap px-6 py-4">
                    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                      student.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                    }`}>
                      {student.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="whitespace-nowrap px-6 py-4">
                    <button className="text-sm text-blue-600 hover:text-blue-800 font-medium">View</button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Add Student Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowAddModal(false)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add New Student</h2>
            {addError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {addError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleAddStudent(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input
                  type="text"
                  required
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="Enter student name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name (Myanmar)</label>
                <input
                  type="text"
                  value={newNameMy}
                  onChange={(e) => setNewNameMy(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="Enter Myanmar name"
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Grade</label>
                  <select
                    value={newGrade}
                    onChange={(e) => setNewGrade(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  >
                    {[1,2,3,4,5,6,7,8,9,10,11].map(g => (
                      <option key={g} value={g}>Grade {g}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Section</label>
                  <select
                    value={newSection}
                    onChange={(e) => setNewSection(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  >
                    {['A','B','C','D'].map(s => (
                      <option key={s} value={s}>{s}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Parent Phone (optional)</label>
                <input
                  type="tel"
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="09xxxxxxxxx"
                />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => { setShowAddModal(false); setAddError(''); }} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={addLoading} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
                  {addLoading ? 'Adding...' : 'Add Student'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
