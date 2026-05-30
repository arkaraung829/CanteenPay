import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const date = searchParams.get('date') || new Date().toISOString().split('T')[0];
  const grade = searchParams.get('grade') || '';
  const className = searchParams.get('class_name') || '';
  const schoolId = searchParams.get('school_id') || '';

  // Build student query with filters
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
    return NextResponse.json({ success: true, students: [] });
  }

  // Fetch existing attendance records for this date
  const studentIds = students.map(s => s.id);
  const { data: attendanceRecords, error: attError } = await supabase
    .from('attendance')
    .select('student_id, status, notes')
    .eq('date', date)
    .in('student_id', studentIds);

  if (attError) {
    return Response.json({ success: false, error: attError.message }, { status: 500 });
  }

  // Create a map of student_id -> attendance
  const attendanceMap = new Map(
    (attendanceRecords || []).map(a => [a.student_id, { status: a.status, notes: a.notes }])
  );

  // Merge students with their attendance
  const merged = students.map(s => ({
    id: s.id,
    full_name: s.full_name,
    student_code: s.student_code,
    status: attendanceMap.get(s.id)?.status || null,
    notes: attendanceMap.get(s.id)?.notes || null,
  }));

  return NextResponse.json({ success: true, students: merged });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { date, school_id, records } = body;

    if (!date || !records || !Array.isArray(records) || records.length === 0) {
      return Response.json(
        { success: false, error: 'date and records[] are required' },
        { status: 400 }
      );
    }

    // Build upsert rows
    const rows = records.map((r: { student_id: string; status: string; notes?: string }) => ({
      student_id: r.student_id,
      school_id: school_id || null,
      date,
      status: r.status,
      notes: r.notes || null,
      marked_by: auth.userId,
    }));

    const { data, error } = await supabase
      .from('attendance')
      .upsert(rows, { onConflict: 'student_id,date' })
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
