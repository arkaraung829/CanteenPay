'use client';

import { authFetch } from '@/lib/auth-fetch';
import { useSchoolContext } from '@/lib/school-context';
import { useState, useEffect, useCallback } from 'react';
import {
  Users, Check, X, Clock, Loader2, ClipboardCheck,
} from 'lucide-react';

interface StudentAttendance {
  id: string;
  full_name: string;
  student_code: string;
  status: 'present' | 'absent' | 'late' | null;
  notes: string | null;
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

export default function AttendancePage() {
  const { selectedSchoolId } = useSchoolContext();

  // Filters
  const [date, setDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [grade, setGrade] = useState('');
  const [className, setClassName] = useState('');

  // Options for dropdowns
  const [grades, setGrades] = useState<GradeOption[]>([]);
  const [sections, setSections] = useState<SectionOption[]>([]);

  // Student data
  const [students, setStudents] = useState<StudentAttendance[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Track local edits
  const [localRecords, setLocalRecords] = useState<Map<string, { status: string; notes: string }>>(new Map());

  // Fetch grades and sections
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
          const active = (gradesJson.data || []).filter((g: GradeOption) => g.is_active);
          setGrades(active);
          if (active.length > 0 && !grade) setGrade(active[0].name);
        }
        if (sectionsJson.success) {
          const active = (sectionsJson.data || []).filter((s: SectionOption) => s.is_active);
          setSections(active);
          if (active.length > 0 && !className) setClassName(active[0].name);
        }
      } catch {
        // Fall back gracefully
      }
    }
    fetchOptions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSchoolId]);

  // Derive the class_name filter value (matching student page pattern: "Grade X-Y")
  const classNameFilter = grade && className ? `Grade ${grade}-${className}` : '';

  // Fetch students + attendance
  const fetchAttendance = useCallback(async () => {
    if (!grade || !className) return;
    setLoading(true);
    setError('');
    setSuccessMsg('');
    try {
      const params = new URLSearchParams({ date, grade, class_name: classNameFilter });
      if (selectedSchoolId) params.set('school_id', selectedSchoolId);
      const res = await authFetch(`/api/attendance?${params}`);
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to fetch attendance');
        setLoading(false);
        return;
      }
      const fetched: StudentAttendance[] = json.students || [];
      setStudents(fetched);

      // Initialize local records from fetched data
      const map = new Map<string, { status: string; notes: string }>();
      fetched.forEach(s => {
        map.set(s.id, {
          status: s.status || '',
          notes: s.notes || '',
        });
      });
      setLocalRecords(map);
    } catch {
      setError('Network error fetching attendance');
    }
    setLoading(false);
  }, [date, grade, className, classNameFilter, selectedSchoolId]);

  useEffect(() => {
    if (grade && className) {
      fetchAttendance();
    }
  }, [fetchAttendance, grade, className]);

  // Update a student's status locally
  function setStudentStatus(studentId: string, status: string) {
    setLocalRecords(prev => {
      const next = new Map(prev);
      const existing = next.get(studentId) || { status: '', notes: '' };
      next.set(studentId, { ...existing, status });
      return next;
    });
  }

  // Update a student's notes locally
  function setStudentNotes(studentId: string, notes: string) {
    setLocalRecords(prev => {
      const next = new Map(prev);
      const existing = next.get(studentId) || { status: '', notes: '' };
      next.set(studentId, { ...existing, notes });
      return next;
    });
  }

  // Mark all present
  function markAllPresent() {
    setLocalRecords(prev => {
      const next = new Map(prev);
      students.forEach(s => {
        const existing = next.get(s.id) || { status: '', notes: '' };
        next.set(s.id, { ...existing, status: 'present' });
      });
      return next;
    });
  }

  // Save attendance
  async function handleSave() {
    setSaving(true);
    setError('');
    setSuccessMsg('');

    const records = students
      .map(s => {
        const local = localRecords.get(s.id);
        if (!local?.status) return null;
        return {
          student_id: s.id,
          status: local.status,
          notes: local.notes || null,
        };
      })
      .filter(Boolean);

    if (records.length === 0) {
      setError('No attendance records to save. Please mark at least one student.');
      setSaving(false);
      return;
    }

    try {
      const res = await authFetch('/api/attendance', {
        method: 'POST',
        body: JSON.stringify({
          date,
          school_id: selectedSchoolId || null,
          records,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to save attendance');
      } else {
        setSuccessMsg(`Attendance saved for ${json.count} student(s).`);
        // Clear success message after 3 seconds
        setTimeout(() => setSuccessMsg(''), 3000);
      }
    } catch {
      setError('Network error saving attendance');
    }
    setSaving(false);
  }

  // Summary counts
  const presentCount = Array.from(localRecords.values()).filter(r => r.status === 'present').length;
  const absentCount = Array.from(localRecords.values()).filter(r => r.status === 'absent').length;
  const lateCount = Array.from(localRecords.values()).filter(r => r.status === 'late').length;

  return (
    <div>
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Attendance</h1>
          <p className="mt-1 text-sm text-gray-500">Mark daily attendance for students</p>
        </div>
      </div>

      {/* Top bar: Date, Grade, Section */}
      <div className="mb-6 flex flex-col sm:flex-row gap-3">
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Date</label>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Grade</label>
          <select
            value={grade}
            onChange={(e) => setGrade(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            <option value="">Select Grade</option>
            {grades.map(g => (
              <option key={g.id} value={g.name}>{g.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Section</label>
          <select
            value={className}
            onChange={(e) => setClassName(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            <option value="">Select Section</option>
            {sections.map(s => (
              <option key={s.id} value={s.name}>{s.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Summary cards */}
      <div className="mb-6 grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-100">
              <Users className="h-5 w-5 text-blue-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-gray-900">{students.length}</p>
              <p className="text-xs text-gray-500">Total Students</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-green-100">
              <Check className="h-5 w-5 text-green-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-green-700">{presentCount}</p>
              <p className="text-xs text-gray-500">Present</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-100">
              <X className="h-5 w-5 text-red-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-red-700">{absentCount}</p>
              <p className="text-xs text-gray-500">Absent</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-yellow-100">
              <Clock className="h-5 w-5 text-yellow-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-yellow-700">{lateCount}</p>
              <p className="text-xs text-gray-500">Late</p>
            </div>
          </div>
        </div>
      </div>

      {/* Action bar */}
      {students.length > 0 && (
        <div className="mb-4 flex items-center justify-between">
          <button
            onClick={markAllPresent}
            className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            <Check className="h-4 w-4 text-green-600" />
            Mark All Present
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
          >
            {saving ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <ClipboardCheck className="h-4 w-4" />
            )}
            {saving ? 'Saving...' : 'Save Attendance'}
          </button>
        </div>
      )}

      {/* Success message */}
      {successMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700">
          {successMsg}
        </div>
      )}

      {/* Error message */}
      {error && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Content */}
      {!grade || !className ? (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-col items-center justify-center py-16 px-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
              <ClipboardCheck className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">Select a class</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              Choose a grade and section above to start marking attendance.
            </p>
          </div>
        </div>
      ) : loading ? (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="bg-gray-50 px-6 py-3">
            <div className="flex gap-6">
              {[1, 2, 3, 4].map(i => (
                <div key={i} className="h-4 w-20 animate-pulse rounded bg-gray-200" />
              ))}
            </div>
          </div>
          <div className="divide-y divide-gray-200">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="flex items-center gap-6 px-6 py-4">
                <div className="h-9 w-9 animate-pulse rounded-full bg-gray-200" />
                <div className="h-4 w-32 animate-pulse rounded bg-gray-200" />
                <div className="h-4 w-24 animate-pulse rounded bg-gray-200" />
                <div className="h-8 w-48 animate-pulse rounded bg-gray-200" />
                <div className="h-8 w-32 animate-pulse rounded bg-gray-200" />
              </div>
            ))}
          </div>
        </div>
      ) : students.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-col items-center justify-center py-16 px-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
              <Users className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">No students found</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              No active students found for this class. Check your grade and section filters.
            </p>
          </div>
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Student</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">ID</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {students.map((student) => {
                  const local = localRecords.get(student.id) || { status: '', notes: '' };
                  return (
                    <tr key={student.id} className="hover:bg-gray-50">
                      <td className="whitespace-nowrap px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">
                            {student.full_name.charAt(0)}
                          </div>
                          <span className="text-sm font-medium text-gray-900">{student.full_name}</span>
                        </div>
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-sm text-gray-500 font-mono">
                        {student.student_code}
                      </td>
                      <td className="whitespace-nowrap px-4 py-4">
                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => setStudentStatus(student.id, 'present')}
                            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                              local.status === 'present'
                                ? 'bg-green-600 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-green-50 hover:text-green-700'
                            }`}
                          >
                            Present
                          </button>
                          <button
                            onClick={() => setStudentStatus(student.id, 'absent')}
                            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                              local.status === 'absent'
                                ? 'bg-red-600 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-red-50 hover:text-red-700'
                            }`}
                          >
                            Absent
                          </button>
                          <button
                            onClick={() => setStudentStatus(student.id, 'late')}
                            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                              local.status === 'late'
                                ? 'bg-yellow-500 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-yellow-50 hover:text-yellow-700'
                            }`}
                          >
                            Late
                          </button>
                        </div>
                      </td>
                      <td className="px-4 py-4">
                        <input
                          type="text"
                          value={local.notes}
                          onChange={(e) => setStudentNotes(student.id, e.target.value)}
                          placeholder="Optional notes..."
                          className="w-full min-w-[160px] rounded-lg border border-gray-200 px-3 py-1.5 text-sm text-gray-700 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
