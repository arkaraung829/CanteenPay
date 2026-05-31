import { createAdminClient } from '@/lib/supabase';
import { verifyAdminOrTeacher, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

interface GradeScaleEntry {
  letter: string;
  label: string;
  min: number;
  color: string;
}

const DEFAULT_GRADING_SCALE: GradeScaleEntry[] = [
  { letter: 'A', label: 'Distinction', min: 80, color: 'green' },
  { letter: 'B', label: 'Credit', min: 65, color: 'blue' },
  { letter: 'C', label: 'Pass', min: 40, color: 'yellow' },
  { letter: 'F', label: 'Fail', min: 0, color: 'red' },
];

/** Convert old { a_min, b_min, c_min } format to new array format */
function normalizeGradingScale(raw: unknown): GradeScaleEntry[] {
  if (Array.isArray(raw)) return raw as GradeScaleEntry[];
  if (raw && typeof raw === 'object' && 'a_min' in (raw as Record<string, unknown>)) {
    const obj = raw as { a_min?: number; b_min?: number; c_min?: number };
    return [
      { letter: 'A', label: 'Distinction', min: obj.a_min ?? 80, color: 'green' },
      { letter: 'B', label: 'Credit', min: obj.b_min ?? 65, color: 'blue' },
      { letter: 'C', label: 'Pass', min: obj.c_min ?? 40, color: 'yellow' },
      { letter: 'F', label: 'Fail', min: 0, color: 'red' },
    ];
  }
  return DEFAULT_GRADING_SCALE;
}

function computeLetterGrade(score: number | null, fullMarks: number, scale: GradeScaleEntry[] = DEFAULT_GRADING_SCALE): string | null {
  if (score === null || score === undefined || fullMarks === 0) return null;
  const pct = (score / fullMarks) * 100;
  const sorted = [...scale].sort((a, b) => b.min - a.min);
  for (const level of sorted) {
    if (pct >= level.min) return level.letter;
  }
  return sorted[sorted.length - 1]?.letter || 'F';
}

export async function GET(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const grade = searchParams.get('grade') || '';
  const className = searchParams.get('class_name') || '';
  const examTypeId = searchParams.get('exam_type_id') || '';
  const academicYear = searchParams.get('academic_year') || '';
  const schoolId = searchParams.get('school_id') || '';
  const studentId = searchParams.get('student_id') || '';

  // Individual student grades lookup (for report card expand)
  if (studentId && academicYear) {
    const { data: gradesData } = await supabase
      .from('student_grades')
      .select('score, full_marks, letter_grade, subjects(name)')
      .eq('student_id', studentId)
      .eq('academic_year', academicYear);

    const scores: Record<string, { score: number | null; full_marks: number; letter_grade: string | null }> = {};
    for (const g of (gradesData || []) as Array<{ score: number | null; full_marks: number; letter_grade: string | null; subjects: { name: string } | { name: string }[] | null }>) {
      const subName = Array.isArray(g.subjects) ? g.subjects[0]?.name : g.subjects?.name || 'Unknown';
      scores[subName] = { score: g.score, full_marks: g.full_marks, letter_grade: g.letter_grade };
    }

    return NextResponse.json({ success: true, data: [{ student_id: studentId, scores }] });
  }

  if (!grade || !examTypeId || !academicYear) {
    return Response.json(
      { success: false, error: 'grade, exam_type_id, and academic_year are required' },
      { status: 400 }
    );
  }

  // Fetch students for the grade+class
  let studentQuery = supabase
    .from('students')
    .select('id, full_name, student_code, grade, class_name')
    .eq('is_active', true)
    .order('full_name', { ascending: true });

  if (schoolId) studentQuery = studentQuery.eq('school_id', schoolId);
  if (grade) studentQuery = studentQuery.eq('grade', grade);
  if (className) studentQuery = studentQuery.eq('class_name', className);

  const { data: students, error: studentsError } = await studentQuery;

  if (studentsError) {
    return Response.json({ success: false, error: studentsError.message }, { status: 500 });
  }

  if (!students || students.length === 0) {
    return NextResponse.json({ success: true, students: [], subjects: [] });
  }

  // Fetch subjects for this grade level
  let subjectQuery = supabase
    .from('subjects')
    .select('id, name, name_my, full_marks, pass_marks')
    .eq('is_active', true)
    .contains('grade_levels', [grade])
    .order('display_order', { ascending: true });

  if (schoolId) subjectQuery = subjectQuery.eq('school_id', schoolId);

  const { data: subjects, error: subjectsError } = await subjectQuery;

  if (subjectsError) {
    return Response.json({ success: false, error: subjectsError.message }, { status: 500 });
  }

  // Fetch existing grades
  const studentIds = students.map(s => s.id);
  const { data: grades, error: gradesError } = await supabase
    .from('student_grades')
    .select('id, student_id, subject_id, score, full_marks, letter_grade, remarks')
    .eq('exam_type_id', examTypeId)
    .eq('academic_year', academicYear)
    .in('student_id', studentIds);

  if (gradesError) {
    return Response.json({ success: false, error: gradesError.message }, { status: 500 });
  }

  // Build a map: student_id -> subject_id -> grade data
  const gradeMap = new Map<string, Map<string, { score: number | null; letter_grade: string | null; remarks: string | null }>>();
  (grades || []).forEach((g: { student_id: string; subject_id: string; score: number | null; letter_grade: string | null; remarks: string | null }) => {
    if (!gradeMap.has(g.student_id)) gradeMap.set(g.student_id, new Map());
    gradeMap.get(g.student_id)!.set(g.subject_id, {
      score: g.score,
      letter_grade: g.letter_grade,
      remarks: g.remarks,
    });
  });

  // Merge students with their scores
  const merged = students.map(s => {
    const studentGrades = gradeMap.get(s.id) || new Map();
    const scores: Record<string, { score: number | null; letter_grade: string | null; remarks: string | null }> = {};
    (subjects || []).forEach((sub: { id: string; full_marks: number }) => {
      const g = studentGrades.get(sub.id);
      scores[sub.id] = g || { score: null, letter_grade: null, remarks: null };
    });
    return {
      id: s.id,
      full_name: s.full_name,
      student_code: s.student_code,
      scores,
    };
  });

  return NextResponse.json({
    success: true,
    students: merged,
    subjects: subjects || [],
  });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { academic_year, exam_type_id, records } = body;

    if (!academic_year || !exam_type_id || !records || !Array.isArray(records) || records.length === 0) {
      return Response.json(
        { success: false, error: 'academic_year, exam_type_id, and records[] are required' },
        { status: 400 }
      );
    }

    // Get subject full_marks and school_id for letter grade computation
    const subjectIds = [...new Set(records.map((r: { subject_id: string }) => r.subject_id))];
    const { data: subjects } = await supabase
      .from('subjects')
      .select('id, full_marks, school_id')
      .in('id', subjectIds);

    const subjectMap = new Map((subjects || []).map((s: { id: string; full_marks: number }) => [s.id, s.full_marks]));

    // Fetch grading scale from school settings
    let gradingScale: GradeScaleEntry[] = DEFAULT_GRADING_SCALE;
    const schoolId = subjects?.[0]?.school_id;
    if (schoolId) {
      const { data: schoolData } = await supabase
        .from('schools')
        .select('settings')
        .eq('id', schoolId)
        .single();
      if (schoolData?.settings?.grading_scale) {
        gradingScale = normalizeGradingScale(schoolData.settings.grading_scale);
      }
    }

    // Build upsert rows
    const rows = records.map((r: { student_id: string; subject_id: string; score: number | null; remarks?: string }) => {
      const fullMarks = subjectMap.get(r.subject_id) || 100;
      return {
        student_id: r.student_id,
        subject_id: r.subject_id,
        exam_type_id,
        academic_year,
        score: r.score,
        full_marks: fullMarks,
        letter_grade: computeLetterGrade(r.score, fullMarks, gradingScale),
        remarks: r.remarks || null,
        graded_by: auth.userId,
      };
    });

    const { data, error } = await supabase
      .from('student_grades')
      .upsert(rows, { onConflict: 'student_id,subject_id,exam_type_id,academic_year' })
      .select();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data, count: data?.length || 0 });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
