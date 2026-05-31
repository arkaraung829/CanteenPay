'use client';

import React from 'react';
import { authFetch } from '@/lib/auth-fetch';
import { useSchoolContext } from '@/lib/school-context';
import { supabase } from '@/lib/supabase';
import { useState, useEffect, useCallback } from 'react';
import {
  Loader2, FileText, Download, ChevronDown, ChevronUp, Save, RefreshCw,
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

interface TeacherRecord {
  assigned_grades: string[];
  assigned_classes: string[];
}

interface ReportCard {
  id: string;
  student_id: string;
  school_id: string;
  academic_year: string;
  term: string;
  total_score: number | null;
  total_full_marks: number | null;
  percentage: number | null;
  rank_in_class: number | null;
  overall_grade: string | null;
  result: string | null;
  teacher_comment: string | null;
  principal_comment: string | null;
  generated_at: string;
  students: {
    id: string;
    full_name: string;
    student_code: string;
    grade: string;
    class_name: string;
  };
}

interface StudentGradeDetail {
  subject_name: string;
  score: number | null;
  full_marks: number;
  letter_grade: string | null;
}

function getCurrentAcademicYear(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  if (month >= 6) return `${year}-${year + 1}`;
  return `${year - 1}-${year}`;
}

function resultColor(result: string | null): string {
  switch (result) {
    case 'Distinction': return 'bg-green-100 text-green-700';
    case 'Credit': return 'bg-blue-100 text-blue-700';
    case 'Pass': return 'bg-yellow-100 text-yellow-700';
    case 'Fail': return 'bg-red-100 text-red-700';
    default: return 'bg-gray-100 text-gray-600';
  }
}

function gradeColor(grade: string | null): string {
  switch (grade) {
    case 'A': return 'text-green-600';
    case 'B': return 'text-blue-600';
    case 'C': return 'text-yellow-600';
    case 'F': return 'text-red-600';
    default: return 'text-gray-500';
  }
}

function downloadCSV(filename: string, csvContent: string) {
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export default function ReportCardsPage() {
  const { selectedSchoolId, userRole } = useSchoolContext();

  // Filters
  const [grade, setGrade] = useState('');
  const [className, setClassName] = useState('');
  const [academicYear, setAcademicYear] = useState(getCurrentAcademicYear);
  const [term, setTerm] = useState('');

  // Dropdown options
  const [grades, setGrades] = useState<GradeOption[]>([]);
  const [sections, setSections] = useState<SectionOption[]>([]);
  const [terms, setTerms] = useState<string[]>([]);

  // Teacher assignment data
  const [teacherRecord, setTeacherRecord] = useState<TeacherRecord | null>(null);

  // Data
  const [reportCards, setReportCards] = useState<ReportCard[]>([]);
  const [loading, setLoading] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Expanded student details
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [expandedDetails, setExpandedDetails] = useState<StudentGradeDetail[]>([]);
  const [detailsLoading, setDetailsLoading] = useState(false);

  // Comment editing
  const [editingCommentId, setEditingCommentId] = useState<string | null>(null);
  const [editComment, setEditComment] = useState('');
  const [savingComment, setSavingComment] = useState(false);

  // Fetch teacher record
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
          const uniqueTerms = [...new Set(
            (examJson.data || [])
              .filter((e: { term: string | null; is_active: boolean }) => e.is_active && e.term)
              .map((e: { term: string }) => e.term)
          )] as string[];
          setTerms(uniqueTerms);
          if (uniqueTerms.length > 0 && !term) setTerm(uniqueTerms[0]);
        }
      } catch { /* fallback */ }
    }
    fetchOptions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSchoolId, userRole, teacherRecord]);

  const classNameFilter = grade && className ? `${grade}-${className}` : '';

  // Fetch report cards
  const fetchReportCards = useCallback(async () => {
    if (!grade || !academicYear || !term) return;
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        grade,
        academic_year: academicYear,
        term,
      });
      if (className) params.set('class_name', classNameFilter);
      if (selectedSchoolId) params.set('school_id', selectedSchoolId);
      const res = await authFetch(`/api/report-cards?${params}`);
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to fetch report cards');
      } else {
        setReportCards(json.data || []);
      }
    } catch {
      setError('Network error fetching report cards');
    }
    setLoading(false);
  }, [grade, className, classNameFilter, academicYear, term, selectedSchoolId]);

  useEffect(() => {
    if (grade && academicYear && term) {
      fetchReportCards();
    }
  }, [fetchReportCards, grade, className, academicYear, term]);

  // Generate report cards
  async function handleGenerate() {
    if (!grade || !academicYear || !term) return;
    setGenerating(true);
    setError('');
    setSuccessMsg('');
    try {
      const res = await authFetch('/api/report-cards', {
        method: 'POST',
        body: JSON.stringify({
          grade,
          class_name: classNameFilter || undefined,
          academic_year: academicYear,
          term,
          school_id: selectedSchoolId || undefined,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to generate report cards');
      } else {
        setSuccessMsg(`Generated ${json.count} report card(s).`);
        setTimeout(() => setSuccessMsg(''), 3000);
        await fetchReportCards();
      }
    } catch {
      setError('Network error generating report cards');
    }
    setGenerating(false);
  }

  // Expand to see subject breakdown
  async function toggleExpand(reportCard: ReportCard) {
    if (expandedId === reportCard.id) {
      setExpandedId(null);
      return;
    }
    setExpandedId(reportCard.id);
    setDetailsLoading(true);
    setEditingCommentId(null);

    try {
      // Fetch student grades for this student/year
      const { data: gradesData } = await supabase
        .from('student_grades')
        .select('score, full_marks, letter_grade, subjects(name)')
        .eq('student_id', reportCard.student_id)
        .eq('academic_year', reportCard.academic_year);

      const details: StudentGradeDetail[] = (gradesData || []).map((g: { score: number | null; full_marks: number; letter_grade: string | null; subjects: { name: string } | { name: string }[] | null }) => ({
        subject_name: Array.isArray(g.subjects) ? g.subjects[0]?.name : g.subjects?.name || 'Unknown',
        score: g.score,
        full_marks: g.full_marks,
        letter_grade: g.letter_grade,
      }));
      setExpandedDetails(details);
    } catch {
      setExpandedDetails([]);
    }
    setDetailsLoading(false);
  }

  // Save teacher comment
  async function handleSaveComment(reportCardId: string) {
    setSavingComment(true);
    try {
      const res = await authFetch('/api/report-cards', {
        method: 'PATCH',
        body: JSON.stringify({
          id: reportCardId,
          teacher_comment: editComment,
        }),
      });
      const json = await res.json();
      if (json.success) {
        setEditingCommentId(null);
        await fetchReportCards();
      } else {
        setError(json.error || 'Failed to save comment');
      }
    } catch {
      setError('Network error saving comment');
    }
    setSavingComment(false);
  }

  // Export CSV
  function handleExportCSV() {
    if (reportCards.length === 0) return;
    const lines: string[] = [];
    lines.push('Student Name,Student Code,Total Score,Total Full Marks,Percentage,Rank,Grade,Result,Teacher Comment');
    reportCards.forEach(rc => {
      const s = rc.students;
      lines.push(
        `"${s.full_name}","${s.student_code}",${rc.total_score ?? ''},${rc.total_full_marks ?? ''},${rc.percentage ?? ''},${rc.rank_in_class ?? ''},"${rc.overall_grade || ''}","${rc.result || ''}","${(rc.teacher_comment || '').replace(/"/g, '""')}"`
      );
    });
    const csv = lines.join('\n');
    const filename = `report-cards-${grade}-${className}-${academicYear}-${term}.csv`.replace(/\s+/g, '-');
    downloadCSV(filename, csv);
  }

  const filtersReady = grade && academicYear && term;

  return (
    <div>
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Report Cards</h1>
          <p className="mt-1 text-sm text-gray-500">Generate and view student report cards</p>
        </div>
        <div className="flex gap-2 self-start">
          {reportCards.length > 0 && (
            <button
              onClick={handleExportCSV}
              className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
            >
              <Download className="h-4 w-4" /> Export CSV
            </button>
          )}
          {userRole !== 'teacher' && filtersReady && (
            <button
              onClick={handleGenerate}
              disabled={generating}
              className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
            >
              {generating ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <RefreshCw className="h-4 w-4" />
              )}
              {generating ? 'Generating...' : 'Generate Report Cards'}
            </button>
          )}
        </div>
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
            <option value="">All Sections</option>
            {sections.map(s => (
              <option key={s.id} value={s.name}>{s.name}</option>
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
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Term</label>
          <select
            value={term}
            onChange={(e) => setTerm(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            <option value="">Select Term</option>
            {terms.map(t => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
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
              <FileText className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">Select filters</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              Choose a grade, academic year, and term to view report cards.
            </p>
          </div>
        </div>
      ) : loading ? (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex items-center justify-center py-16">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
          </div>
        </div>
      ) : reportCards.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-col items-center justify-center py-16 px-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
              <FileText className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">No report cards</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              No report cards found. Click &quot;Generate Report Cards&quot; to create them from existing grade data.
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
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">Total Score</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">Percentage</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">Rank</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">Grade</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">Result</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">Details</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {reportCards.map((rc) => (
                  <React.Fragment key={rc.id}>
                    <tr className="hover:bg-gray-50">
                      <td className="whitespace-nowrap px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">
                            {rc.students.full_name.charAt(0)}
                          </div>
                          <div>
                            <div className="text-sm font-medium text-gray-900">{rc.students.full_name}</div>
                            <div className="text-xs text-gray-400 font-mono">{rc.students.student_code}</div>
                          </div>
                        </div>
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-center text-sm text-gray-700">
                        {rc.total_score ?? '-'} / {rc.total_full_marks ?? '-'}
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-center text-sm font-medium text-gray-900">
                        {rc.percentage !== null ? `${rc.percentage}%` : '-'}
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-center text-sm font-bold text-gray-900">
                        {rc.rank_in_class ?? '-'}
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-center">
                        <span className={`text-lg font-bold ${gradeColor(rc.overall_grade)}`}>
                          {rc.overall_grade || '-'}
                        </span>
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-center">
                        <span className={`inline-block rounded-full px-3 py-1 text-xs font-medium ${resultColor(rc.result)}`}>
                          {rc.result || '-'}
                        </span>
                      </td>
                      <td className="whitespace-nowrap px-4 py-4 text-center">
                        <button
                          onClick={() => toggleExpand(rc)}
                          className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
                        >
                          {expandedId === rc.id ? (
                            <ChevronUp className="h-5 w-5" />
                          ) : (
                            <ChevronDown className="h-5 w-5" />
                          )}
                        </button>
                      </td>
                    </tr>

                    {/* Expanded details */}
                    {expandedId === rc.id && (
                      <tr>
                        <td colSpan={7} className="bg-gray-50 px-6 py-4">
                          {detailsLoading ? (
                            <div className="flex justify-center py-4">
                              <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                            </div>
                          ) : (
                            <div className="space-y-4">
                              {/* Subject breakdown */}
                              <div>
                                <h4 className="text-sm font-semibold text-gray-700 mb-2">Subject Breakdown</h4>
                                <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2">
                                  {expandedDetails.map((d, idx) => (
                                    <div key={idx} className="rounded-lg border border-gray-200 bg-white px-3 py-2">
                                      <div className="text-xs text-gray-500">{d.subject_name}</div>
                                      <div className="flex items-center gap-2 mt-1">
                                        <span className="text-sm font-medium text-gray-900">
                                          {d.score !== null ? d.score : '-'} / {d.full_marks}
                                        </span>
                                        <span className={`text-xs font-bold ${gradeColor(d.letter_grade)}`}>
                                          {d.letter_grade || ''}
                                        </span>
                                      </div>
                                    </div>
                                  ))}
                                  {expandedDetails.length === 0 && (
                                    <p className="text-sm text-gray-400 col-span-full">No grade details available.</p>
                                  )}
                                </div>
                              </div>

                              {/* Teacher comment */}
                              <div>
                                <h4 className="text-sm font-semibold text-gray-700 mb-2">Teacher Comment</h4>
                                {editingCommentId === rc.id ? (
                                  <div className="flex items-start gap-2">
                                    <textarea
                                      value={editComment}
                                      onChange={(e) => setEditComment(e.target.value)}
                                      rows={2}
                                      className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                                      placeholder="Add teacher comment..."
                                    />
                                    <button
                                      onClick={() => handleSaveComment(rc.id)}
                                      disabled={savingComment}
                                      className="rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                                    >
                                      {savingComment ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
                                    </button>
                                    <button
                                      onClick={() => setEditingCommentId(null)}
                                      className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50"
                                    >
                                      Cancel
                                    </button>
                                  </div>
                                ) : (
                                  <div className="flex items-center gap-2">
                                    <p className="text-sm text-gray-600">
                                      {rc.teacher_comment || <span className="text-gray-400 italic">No comment</span>}
                                    </p>
                                    <button
                                      onClick={() => {
                                        setEditingCommentId(rc.id);
                                        setEditComment(rc.teacher_comment || '');
                                      }}
                                      className="text-xs text-blue-600 hover:text-blue-800 font-medium"
                                    >
                                      Edit
                                    </button>
                                  </div>
                                )}
                              </div>
                            </div>
                          )}
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
