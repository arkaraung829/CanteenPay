'use client';

import { authFetch } from '@/lib/auth-fetch';
import { useSchoolContext } from '@/lib/school-context';
import { supabase } from '@/lib/supabase';
import { useState, useEffect, useCallback } from 'react';
import {
  Loader2, BookOpen, Save,
} from 'lucide-react';

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

interface ExamTypeOption {
  id: string;
  name: string;
  term: string | null;
  is_active: boolean;
}

interface SubjectData {
  id: string;
  name: string;
  name_my: string | null;
  full_marks: number;
  pass_marks: number;
}

interface StudentScores {
  id: string;
  full_name: string;
  student_code: string;
  scores: Record<string, { score: number | null; letter_grade: string | null; remarks: string | null }>;
}

interface TeacherRecord {
  assigned_grades: string[];
  assigned_classes: string[];
}

function computeLetterGrade(score: number | null, fullMarks: number): string | null {
  if (score === null || score === undefined || fullMarks === 0) return null;
  const pct = (score / fullMarks) * 100;
  if (pct >= 80) return 'A';
  if (pct >= 60) return 'B';
  if (pct >= 40) return 'C';
  return 'F';
}

function letterGradeColor(grade: string | null): string {
  switch (grade) {
    case 'A': return 'text-green-600';
    case 'B': return 'text-blue-600';
    case 'C': return 'text-yellow-600';
    case 'F': return 'text-red-600';
    default: return 'text-gray-400';
  }
}

function getCurrentAcademicYear(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  // Myanmar academic year typically starts in June
  if (month >= 6) return `${year}-${year + 1}`;
  return `${year - 1}-${year}`;
}

export default function GradesPage() {
  const { selectedSchoolId, userRole } = useSchoolContext();

  // Filters
  const [grade, setGrade] = useState('');
  const [className, setClassName] = useState('');
  const [examTypeId, setExamTypeId] = useState('');
  const [academicYear, setAcademicYear] = useState(getCurrentAcademicYear);

  // Dropdown options
  const [grades, setGrades] = useState<GradeOption[]>([]);
  const [sections, setSections] = useState<SectionOption[]>([]);
  const [examTypes, setExamTypes] = useState<ExamTypeOption[]>([]);

  // Teacher assignment data
  const [teacherRecord, setTeacherRecord] = useState<TeacherRecord | null>(null);

  // Data
  const [subjects, setSubjects] = useState<SubjectData[]>([]);
  const [students, setStudents] = useState<StudentScores[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Local edits: student_id -> subject_id -> score
  const [localScores, setLocalScores] = useState<Map<string, Map<string, number | null>>>(new Map());

  // Fetch teacher record if user is a teacher
  useEffect(() => {
    async function fetchTeacherRecord() {
      if (userRole !== 'teacher') return;
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;
        const { data } = await supabase
          .from('teachers')
          .select('assigned_grades, assigned_classes')
          .eq('profile_id', user.id)
          .eq('is_active', true)
          .single();
        if (data) setTeacherRecord(data);
      } catch { /* fallback */ }
    }
    fetchTeacherRecord();
  }, [userRole]);

  // Fetch filter options
  useEffect(() => {
    async function fetchOptions() {
      try {
        const gradeParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const sectionParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const examParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const [gradesRes, sectionsRes, examRes] = await Promise.all([
          authFetch(`/api/settings/grades${gradeParams}`),
          authFetch(`/api/settings/sections${sectionParams}`),
          authFetch(`/api/exam-types${examParams}`),
        ]);
        const gradesJson = await gradesRes.json();
        const sectionsJson = await sectionsRes.json();
        const examJson = await examRes.json();

        if (gradesJson.success) {
          let active = (gradesJson.data || []).filter((g: GradeOption) => g.is_active);
          if (userRole === 'teacher' && teacherRecord) {
            active = active.filter((g: GradeOption) => teacherRecord.assigned_grades.includes(g.name));
          }
          setGrades(active);
          if (active.length > 0 && !grade) setGrade(active[0].name);
        }
        if (sectionsJson.success) {
          let active = (sectionsJson.data || []).filter((s: SectionOption) => s.is_active);
          if (userRole === 'teacher' && teacherRecord) {
            active = active.filter((s: SectionOption) =>
              teacherRecord.assigned_classes.some(cls => cls.endsWith(`-${s.name}`))
            );
          }
          setSections(active);
          if (active.length > 0 && !className) setClassName(active[0].name);
        }
        if (examJson.success) {
          const active = (examJson.data || []).filter((e: ExamTypeOption) => e.is_active);
          setExamTypes(active);
          if (active.length > 0 && !examTypeId) setExamTypeId(active[0].id);
        }
      } catch { /* fallback */ }
    }
    fetchOptions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSchoolId, userRole, teacherRecord]);

  const classNameFilter = grade && className ? `Grade ${grade}-${className}` : '';

  // Fetch grades data
  const fetchGrades = useCallback(async () => {
    if (!grade || !className || !examTypeId || !academicYear) return;
    setLoading(true);
    setError('');
    setSuccessMsg('');
    try {
      const params = new URLSearchParams({
        grade,
        class_name: classNameFilter,
        exam_type_id: examTypeId,
        academic_year: academicYear,
      });
      if (selectedSchoolId) params.set('school_id', selectedSchoolId);
      const res = await authFetch(`/api/student-grades?${params}`);
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to fetch grades');
        setLoading(false);
        return;
      }
      setStudents(json.students || []);
      setSubjects(json.subjects || []);

      // Initialize local scores from fetched data
      const map = new Map<string, Map<string, number | null>>();
      (json.students || []).forEach((s: StudentScores) => {
        const subMap = new Map<string, number | null>();
        Object.entries(s.scores).forEach(([subId, data]) => {
          subMap.set(subId, data.score);
        });
        map.set(s.id, subMap);
      });
      setLocalScores(map);
    } catch {
      setError('Network error fetching grades');
    }
    setLoading(false);
  }, [grade, className, classNameFilter, examTypeId, academicYear, selectedSchoolId]);

  useEffect(() => {
    if (grade && className && examTypeId && academicYear) {
      fetchGrades();
    }
  }, [fetchGrades, grade, className, examTypeId, academicYear]);

  // Update score locally
  function setScore(studentId: string, subjectId: string, value: string) {
    const numVal = value === '' ? null : parseFloat(value);
    setLocalScores(prev => {
      const next = new Map(prev);
      const subMap = new Map(next.get(studentId) || new Map());
      subMap.set(subjectId, numVal);
      next.set(studentId, subMap);
      return next;
    });
  }

  // Get local score for a student/subject
  function getScore(studentId: string, subjectId: string): number | null {
    return localScores.get(studentId)?.get(subjectId) ?? null;
  }

  // Save all
  async function handleSave() {
    setSaving(true);
    setError('');
    setSuccessMsg('');

    const records: { student_id: string; subject_id: string; score: number | null }[] = [];
    localScores.forEach((subMap, studentId) => {
      subMap.forEach((score, subjectId) => {
        records.push({ student_id: studentId, subject_id: subjectId, score });
      });
    });

    if (records.length === 0) {
      setError('No scores to save.');
      setSaving(false);
      return;
    }

    try {
      const res = await authFetch('/api/student-grades', {
        method: 'POST',
        body: JSON.stringify({
          academic_year: academicYear,
          exam_type_id: examTypeId,
          records,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to save grades');
      } else {
        setSuccessMsg(`Grades saved for ${json.count} record(s).`);
        setTimeout(() => setSuccessMsg(''), 3000);
        // Refresh to get computed letter grades
        await fetchGrades();
      }
    } catch {
      setError('Network error saving grades');
    }
    setSaving(false);
  }

  // Compute averages per subject
  function getSubjectAverage(subjectId: string): string {
    let total = 0;
    let count = 0;
    students.forEach(s => {
      const score = getScore(s.id, subjectId);
      if (score !== null && score !== undefined) {
        total += score;
        count++;
      }
    });
    if (count === 0) return '-';
    return (total / count).toFixed(1);
  }

  const filtersReady = grade && className && examTypeId && academicYear;

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Grade Entry</h1>
        <p className="mt-1 text-sm text-gray-500">Enter student scores for exams</p>
      </div>

      {/* Filters */}
      <div className="mb-6 flex flex-col sm:flex-row gap-3 flex-wrap">
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
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Exam Type</label>
          <select
            value={examTypeId}
            onChange={(e) => setExamTypeId(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            <option value="">Select Exam</option>
            {examTypes.map(e => (
              <option key={e.id} value={e.id}>{e.name}{e.term ? ` (${e.term})` : ''}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Academic Year</label>
          <input
            type="text"
            value={academicYear}
            onChange={(e) => setAcademicYear(e.target.value)}
            placeholder="e.g. 2025-2026"
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 w-32"
          />
        </div>
      </div>

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
      {!filtersReady ? (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-col items-center justify-center py-16 px-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
              <BookOpen className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">Select filters</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              Choose a grade, section, exam type, and academic year to start entering grades.
            </p>
          </div>
        </div>
      ) : loading ? (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex items-center justify-center py-16">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
          </div>
        </div>
      ) : students.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-col items-center justify-center py-16 px-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
              <BookOpen className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">No students found</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              No active students found for this class. Check your grade and section filters.
            </p>
          </div>
        </div>
      ) : (
        <>
          {/* Save button */}
          <div className="mb-4 flex justify-end">
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
            >
              {saving ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              {saving ? 'Saving...' : 'Save All'}
            </button>
          </div>

          {/* Spreadsheet table */}
          <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="sticky left-0 z-10 bg-gray-50 px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 min-w-[180px]">
                      Student
                    </th>
                    {subjects.map(sub => (
                      <th key={sub.id} className="px-3 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500 min-w-[120px]">
                        <div>{sub.name}</div>
                        <div className="text-[10px] font-normal text-gray-400 normal-case">
                          /{sub.full_marks}
                        </div>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {students.map((student) => (
                    <tr key={student.id} className="hover:bg-gray-50">
                      <td className="sticky left-0 z-10 bg-white whitespace-nowrap px-4 py-3 border-r border-gray-100">
                        <div className="flex items-center gap-2">
                          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700">
                            {student.full_name.charAt(0)}
                          </div>
                          <div>
                            <div className="text-sm font-medium text-gray-900">{student.full_name}</div>
                            <div className="text-xs text-gray-400 font-mono">{student.student_code}</div>
                          </div>
                        </div>
                      </td>
                      {subjects.map(sub => {
                        const score = getScore(student.id, sub.id);
                        const letterGrade = computeLetterGrade(score, sub.full_marks);
                        return (
                          <td key={sub.id} className="px-2 py-2 text-center">
                            <div className="flex items-center justify-center gap-1">
                              <input
                                type="number"
                                value={score !== null && score !== undefined ? score : ''}
                                onChange={(e) => setScore(student.id, sub.id, e.target.value)}
                                min="0"
                                max={sub.full_marks}
                                step="0.5"
                                className="w-16 rounded border border-gray-200 px-2 py-1.5 text-sm text-center focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                                placeholder="-"
                              />
                              <span className={`text-xs font-bold w-4 ${letterGradeColor(letterGrade)}`}>
                                {letterGrade || ''}
                              </span>
                            </div>
                          </td>
                        );
                      })}
                    </tr>
                  ))}

                  {/* Class average row */}
                  <tr className="bg-gray-50 font-medium">
                    <td className="sticky left-0 z-10 bg-gray-50 px-4 py-3 text-sm text-gray-700 border-r border-gray-100">
                      Class Average
                    </td>
                    {subjects.map(sub => (
                      <td key={sub.id} className="px-2 py-3 text-center text-sm text-gray-700">
                        {getSubjectAverage(sub.id)}
                      </td>
                    ))}
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
