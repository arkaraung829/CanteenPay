import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, verifyAdminOrTeacher, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

function computeResult(percentage: number | null): string | null {
  if (percentage === null || percentage === undefined) return null;
  if (percentage >= 80) return 'Distinction';
  if (percentage >= 60) return 'Credit';
  if (percentage >= 40) return 'Pass';
  return 'Fail';
}

function computeOverallGrade(percentage: number | null): string | null {
  if (percentage === null || percentage === undefined) return null;
  if (percentage >= 80) return 'A';
  if (percentage >= 60) return 'B';
  if (percentage >= 40) return 'C';
  return 'F';
}

export async function GET(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const studentId = searchParams.get('student_id') || '';
  const grade = searchParams.get('grade') || '';
  const className = searchParams.get('class_name') || '';
  const academicYear = searchParams.get('academic_year') || '';
  const term = searchParams.get('term') || '';
  const schoolId = searchParams.get('school_id') || '';

  let query = supabase
    .from('report_cards')
    .select('*, students!inner(id, full_name, student_code, grade, class_name)')
    .order('rank_in_class', { ascending: true });

  if (studentId) query = query.eq('student_id', studentId);
  if (schoolId) query = query.eq('school_id', schoolId);
  if (academicYear) query = query.eq('academic_year', academicYear);
  if (term) query = query.eq('term', term);
  if (grade) query = query.eq('students.grade', grade);
  if (className) query = query.eq('students.class_name', className);

  const { data, error } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ success: true, data: data || [] });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { grade, class_name, academic_year, term, school_id } = body;

    if (!grade || !academic_year || !term) {
      return Response.json(
        { success: false, error: 'grade, academic_year, and term are required' },
        { status: 400 }
      );
    }

    let resolvedSchoolId = school_id;
    if (!resolvedSchoolId) {
      const { data: schools } = await supabase.from('schools').select('id').eq('is_active', true).limit(1);
      resolvedSchoolId = schools?.[0]?.id;
    }

    // Fetch students for the class
    let studentQuery = supabase
      .from('students')
      .select('id, full_name, student_code, grade, class_name')
      .eq('is_active', true)
      .eq('grade', grade);

    if (class_name) studentQuery = studentQuery.eq('class_name', class_name);
    if (resolvedSchoolId) studentQuery = studentQuery.eq('school_id', resolvedSchoolId);

    const { data: students, error: studentsError } = await studentQuery;

    if (studentsError) {
      return Response.json({ success: false, error: studentsError.message }, { status: 500 });
    }

    if (!students || students.length === 0) {
      return Response.json({ success: false, error: 'No students found for this class' }, { status: 404 });
    }

    const studentIds = students.map(s => s.id);

    // Fetch all grades for these students for this academic year and the term's exam types
    // Get exam types matching the term
    let examQuery = supabase
      .from('exam_types')
      .select('id')
      .eq('is_active', true);

    if (term) examQuery = examQuery.eq('term', term);
    if (resolvedSchoolId) examQuery = examQuery.eq('school_id', resolvedSchoolId);

    const { data: examTypes } = await examQuery;
    const examTypeIds = (examTypes || []).map((e: { id: string }) => e.id);

    if (examTypeIds.length === 0) {
      return Response.json({ success: false, error: 'No exam types found for this term' }, { status: 404 });
    }

    // Fetch all student grades
    const { data: allGrades, error: gradesError } = await supabase
      .from('student_grades')
      .select('student_id, score, full_marks')
      .eq('academic_year', academic_year)
      .in('exam_type_id', examTypeIds)
      .in('student_id', studentIds);

    if (gradesError) {
      return Response.json({ success: false, error: gradesError.message }, { status: 500 });
    }

    // Aggregate per student
    const studentTotals = new Map<string, { totalScore: number; totalFullMarks: number }>();
    (allGrades || []).forEach((g: { student_id: string; score: number | null; full_marks: number }) => {
      if (g.score === null) return;
      const existing = studentTotals.get(g.student_id) || { totalScore: 0, totalFullMarks: 0 };
      existing.totalScore += Number(g.score);
      existing.totalFullMarks += g.full_marks;
      studentTotals.set(g.student_id, existing);
    });

    // Compute percentages and sort for ranking
    const reportData = students.map(s => {
      const totals = studentTotals.get(s.id) || { totalScore: 0, totalFullMarks: 0 };
      const percentage = totals.totalFullMarks > 0
        ? Math.round((totals.totalScore / totals.totalFullMarks) * 10000) / 100
        : 0;

      return {
        student_id: s.id,
        school_id: resolvedSchoolId,
        academic_year,
        term,
        total_score: totals.totalScore,
        total_full_marks: totals.totalFullMarks,
        percentage,
        overall_grade: computeOverallGrade(percentage),
        result: computeResult(percentage),
        rank_in_class: 0, // computed below
      };
    });

    // Sort by percentage descending to assign ranks
    reportData.sort((a, b) => b.percentage - a.percentage);
    reportData.forEach((r, idx) => {
      r.rank_in_class = idx + 1;
    });

    // Upsert report cards
    const { data, error } = await supabase
      .from('report_cards')
      .upsert(reportData, { onConflict: 'student_id,academic_year,term' })
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

export async function PATCH(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, teacher_comment, principal_comment } = body;

    if (!id) return Response.json({ success: false, error: 'id is required' }, { status: 400 });

    const updates: Record<string, unknown> = {};
    if (teacher_comment !== undefined) updates.teacher_comment = teacher_comment;
    if (principal_comment !== undefined) updates.principal_comment = principal_comment;

    if (Object.keys(updates).length === 0) {
      return Response.json({ success: false, error: 'No valid fields to update' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('report_cards')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

    return NextResponse.json({ success: true, data });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
