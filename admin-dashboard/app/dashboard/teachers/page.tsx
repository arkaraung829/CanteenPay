'use client';

import { authFetch } from '@/lib/auth-fetch';
import { useState, useEffect, useCallback } from 'react';
import { Plus, GraduationCap, X, Loader2 } from 'lucide-react';
import { useSchoolContext } from '@/lib/school-context';

interface TeacherRow {
  id: string;
  profile_id: string;
  full_name: string;
  email: string | null;
  phone: string | null;
  assigned_grades: string[];
  assigned_classes: string[];
  is_active: boolean;
}

interface GradeOption {
  id: string;
  name: string;
  is_active: boolean;
}

interface SectionOption {
  id: string;
  name: string;
  is_active: boolean;
}

export default function TeachersPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [teachers, setTeachers] = useState<TeacherRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState('');

  // Options for multi-select
  const [grades, setGrades] = useState<GradeOption[]>([]);
  const [sections, setSections] = useState<SectionOption[]>([]);

  // Add form state
  const [newFullName, setNewFullName] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newGrades, setNewGrades] = useState<string[]>([]);
  const [newClasses, setNewClasses] = useState<string[]>([]);

  // Edit state
  const [editTeacher, setEditTeacher] = useState<TeacherRow | null>(null);
  const [editFullName, setEditFullName] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editGrades, setEditGrades] = useState<string[]>([]);
  const [editClasses, setEditClasses] = useState<string[]>([]);
  const [editActive, setEditActive] = useState(true);
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState('');

  // Fetch grade and section options
  useEffect(() => {
    async function fetchOptions() {
      try {
        const gradeParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const sectionParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const [gradesRes, sectionsRes] = await Promise.all([
          authFetch(`/api/settings/grades${gradeParams}`),
          authFetch(`/api/settings/sections${sectionParams}`),
        ]);
        const gradesJson = await gradesRes.json();
        const sectionsJson = await sectionsRes.json();
        if (gradesJson.success) {
          setGrades((gradesJson.data || []).filter((g: GradeOption) => g.is_active));
        }
        if (sectionsJson.success) {
          setSections((sectionsJson.data || []).filter((s: SectionOption) => s.is_active));
        }
      } catch {
        // Fall back gracefully
      }
    }
    fetchOptions();
  }, [selectedSchoolId]);

  const fetchTeachers = useCallback(async () => {
    try {
      const params = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
      const res = await authFetch(`/api/teachers${params}`);
      const json = await res.json();
      if (json.success) {
        setTeachers(json.data || []);
      }
    } catch {
      console.error('Failed to fetch teachers');
    }
    setLoading(false);
  }, [selectedSchoolId]);

  useEffect(() => {
    fetchTeachers();
  }, [fetchTeachers]);

  // Build class name options from grade + section combos
  function buildClassOptions(selectedGrades: string[]): string[] {
    if (selectedGrades.length === 0 || sections.length === 0) return [];
    const options: string[] = [];
    for (const g of selectedGrades) {
      for (const s of sections) {
        options.push(`Grade ${g}-${s.name}`);
      }
    }
    return options;
  }

  function toggleArrayItem(arr: string[], item: string): string[] {
    return arr.includes(item) ? arr.filter(x => x !== item) : [...arr, item];
  }

  async function handleAddTeacher() {
    setAddLoading(true);
    setAddError('');

    if (!selectedSchoolId) {
      setAddError('No school selected.');
      setAddLoading(false);
      return;
    }

    try {
      const res = await authFetch('/api/teachers', {
        method: 'POST',
        body: JSON.stringify({
          full_name: newFullName,
          email: newEmail,
          phone: newPhone || null,
          password: newPassword || undefined,
          school_id: selectedSchoolId,
          assigned_grades: newGrades,
          assigned_classes: newClasses,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setAddError(json.error || 'Failed to add teacher');
        setAddLoading(false);
        return;
      }
    } catch {
      setAddError('Network error');
      setAddLoading(false);
      return;
    }

    setShowAddModal(false);
    setNewFullName('');
    setNewEmail('');
    setNewPhone('');
    setNewPassword('');
    setNewGrades([]);
    setNewClasses([]);
    setAddLoading(false);
    fetchTeachers();
  }

  function openEditModal(teacher: TeacherRow) {
    setEditTeacher(teacher);
    setEditFullName(teacher.full_name);
    setEditEmail(teacher.email || '');
    setEditPhone(teacher.phone || '');
    setEditGrades(teacher.assigned_grades || []);
    setEditClasses(teacher.assigned_classes || []);
    setEditActive(teacher.is_active);
    setEditError('');
  }

  async function handleEditTeacher() {
    if (!editTeacher) return;
    setEditLoading(true);
    setEditError('');

    try {
      const res = await authFetch('/api/teachers', {
        method: 'PATCH',
        body: JSON.stringify({
          id: editTeacher.id,
          full_name: editFullName,
          email: editEmail ? editEmail.toLowerCase() : null,
          phone: editPhone || null,
          assigned_grades: editGrades,
          assigned_classes: editClasses,
          is_active: editActive,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setEditError(json.error || 'Failed to update teacher');
        setEditLoading(false);
        return;
      }
    } catch {
      setEditError('Network error');
      setEditLoading(false);
      return;
    }

    setEditTeacher(null);
    setEditLoading(false);
    fetchTeachers();
  }

  async function handleDeactivateTeacher() {
    if (!editTeacher || !confirm('Are you sure you want to deactivate this teacher?')) return;
    setEditLoading(true);

    try {
      const res = await authFetch('/api/teachers', {
        method: 'DELETE',
        body: JSON.stringify({ id: editTeacher.id }),
      });
      const json = await res.json();
      if (!json.success) {
        setEditError(json.error || 'Failed to deactivate teacher');
        setEditLoading(false);
        return;
      }
    } catch {
      setEditError('Network error');
      setEditLoading(false);
      return;
    }

    setEditTeacher(null);
    setEditLoading(false);
    fetchTeachers();
  }

  if (loading) {
    return (
      <div>
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Teachers</h1>
            <p className="mt-1 text-sm text-gray-500">Loading...</p>
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="h-48 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Teachers</h1>
          <p className="mt-1 text-sm text-gray-500">Manage teachers and their class assignments</p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add Teacher
        </button>
      </div>

      {teachers.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center">
          <GraduationCap className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-sm text-gray-400">No teachers registered yet</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {teachers.map((teacher) => (
            <div key={teacher.id} className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${
                    teacher.is_active ? 'bg-purple-100' : 'bg-gray-100'
                  }`}>
                    <GraduationCap className={`h-6 w-6 ${teacher.is_active ? 'text-purple-600' : 'text-gray-400'}`} />
                  </div>
                  <div>
                    <h3 className="text-sm font-semibold text-gray-900">{teacher.full_name}</h3>
                    <p className="text-xs text-gray-500">
                      {teacher.email || 'No email'}
                      {teacher.phone ? ` \u00B7 ${teacher.phone}` : ''}
                    </p>
                  </div>
                </div>
                <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                  teacher.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                }`}>
                  {teacher.is_active ? 'Active' : 'Inactive'}
                </span>
              </div>

              <div className="mt-4">
                <p className="text-xs font-medium text-gray-500 mb-2">Assigned Classes</p>
                <div className="flex flex-wrap gap-1.5">
                  {(teacher.assigned_classes || []).length === 0 ? (
                    <span className="text-xs text-gray-400">No classes assigned</span>
                  ) : (
                    teacher.assigned_classes.map((cls) => (
                      <span
                        key={cls}
                        className="inline-flex items-center rounded-full bg-blue-50 px-2.5 py-0.5 text-xs font-medium text-blue-700"
                      >
                        {cls}
                      </span>
                    ))
                  )}
                </div>
              </div>

              <div className="mt-4 flex gap-2">
                <button
                  onClick={() => openEditModal(teacher)}
                  className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
                >
                  Edit
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Edit Teacher Modal */}
      {editTeacher && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setEditTeacher(null)}>
          <div className="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-gray-900">Edit Teacher</h2>
              <button onClick={() => setEditTeacher(null)} className="rounded-lg p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600">
                <X className="h-5 w-5" />
              </button>
            </div>
            {editError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {editError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleEditTeacher(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input
                  type="text"
                  required
                  value={editFullName}
                  onChange={(e) => setEditFullName(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  value={editEmail}
                  onChange={(e) => setEditEmail(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                <input
                  type="tel"
                  value={editPhone}
                  onChange={(e) => setEditPhone(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="09xxxxxxxxx"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Assigned Grades</label>
                <div className="flex flex-wrap gap-2">
                  {grades.map(g => (
                    <button
                      key={g.id}
                      type="button"
                      onClick={() => setEditGrades(toggleArrayItem(editGrades, g.name))}
                      className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                        editGrades.includes(g.name)
                          ? 'bg-blue-600 text-white'
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                      }`}
                    >
                      {g.name}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Assigned Classes</label>
                <div className="flex flex-wrap gap-2">
                  {buildClassOptions(editGrades).map(cls => (
                    <button
                      key={cls}
                      type="button"
                      onClick={() => setEditClasses(toggleArrayItem(editClasses, cls))}
                      className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                        editClasses.includes(cls)
                          ? 'bg-blue-600 text-white'
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                      }`}
                    >
                      {cls}
                    </button>
                  ))}
                  {buildClassOptions(editGrades).length === 0 && (
                    <p className="text-xs text-gray-400">Select grades first to see class options</p>
                  )}
                </div>
              </div>
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium text-gray-700">Active</label>
                <button
                  type="button"
                  onClick={() => setEditActive(!editActive)}
                  className="shrink-0"
                >
                  <div className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    editActive ? 'bg-green-500' : 'bg-gray-300'
                  }`}>
                    <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      editActive ? 'translate-x-6' : 'translate-x-1'
                    }`} />
                  </div>
                </button>
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={handleDeactivateTeacher}
                  disabled={editLoading}
                  className="rounded-lg border border-red-300 px-4 py-2.5 text-sm font-medium text-red-600 hover:bg-red-50 disabled:opacity-50"
                >
                  Deactivate
                </button>
                <div className="flex-1" />
                <button
                  type="button"
                  onClick={() => setEditTeacher(null)}
                  className="rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={editLoading || !editFullName.trim()}
                  className="rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  {editLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Save'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Teacher Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowAddModal(false)}>
          <div className="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-gray-900">Add Teacher</h2>
              <button onClick={() => { setShowAddModal(false); setAddError(''); }} className="rounded-lg p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600">
                <X className="h-5 w-5" />
              </button>
            </div>
            {addError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {addError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleAddTeacher(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input
                  type="text"
                  required
                  value={newFullName}
                  onChange={(e) => setNewFullName(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="e.g., Daw Hla Hla"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email (for login)</label>
                <input
                  type="email"
                  required
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="teacher@school.edu"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                <input
                  type="text"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="Default: Teacher@123"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                <input
                  type="tel"
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="09xxxxxxxxx"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Assigned Grades</label>
                <div className="flex flex-wrap gap-2">
                  {grades.map(g => (
                    <button
                      key={g.id}
                      type="button"
                      onClick={() => setNewGrades(toggleArrayItem(newGrades, g.name))}
                      className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                        newGrades.includes(g.name)
                          ? 'bg-blue-600 text-white'
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                      }`}
                    >
                      {g.name}
                    </button>
                  ))}
                  {grades.length === 0 && (
                    <p className="text-xs text-gray-400">No grades configured. Add grades in Settings first.</p>
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Assigned Classes</label>
                <div className="flex flex-wrap gap-2">
                  {buildClassOptions(newGrades).map(cls => (
                    <button
                      key={cls}
                      type="button"
                      onClick={() => setNewClasses(toggleArrayItem(newClasses, cls))}
                      className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                        newClasses.includes(cls)
                          ? 'bg-blue-600 text-white'
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                      }`}
                    >
                      {cls}
                    </button>
                  ))}
                  {buildClassOptions(newGrades).length === 0 && (
                    <p className="text-xs text-gray-400">Select grades first to see class options</p>
                  )}
                </div>
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => { setShowAddModal(false); setAddError(''); }}
                  className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={addLoading || !newFullName.trim() || !newEmail.trim()}
                  className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  {addLoading ? 'Adding...' : 'Add Teacher'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
