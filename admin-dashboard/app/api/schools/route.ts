import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function GET() {
  const supabase = createAdminClient();

  // Fetch all schools
  const { data: schools, error } = await supabase
    .from('schools')
    .select('*')
    .order('name');

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  // Fetch stats for each school
  const schoolsWithStats = await Promise.all(
    (schools || []).map(async (school: Record<string, unknown>) => {
      const schoolId = school.id as string;

      const [studentCountRes, balanceRes] = await Promise.all([
        supabase
          .from('students')
          .select('id', { count: 'exact', head: true })
          .eq('school_id', schoolId),
        supabase
          .from('students')
          .select('id')
          .eq('school_id', schoolId)
          .then(async (studentsRes) => {
            if (!studentsRes.data || studentsRes.data.length === 0) return 0;
            const studentIds = studentsRes.data.map((s: { id: string }) => s.id);
            const { data: wallets } = await supabase
              .from('wallets')
              .select('balance')
              .in('student_id', studentIds);
            return (wallets || []).reduce((sum: number, w: { balance: number }) => sum + (w.balance || 0), 0);
          }),
      ]);

      return {
        ...school,
        student_count: studentCountRes.count || 0,
        total_balance: balanceRes,
      };
    })
  );

  return Response.json({ success: true, data: schoolsWithStats });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { name, name_my, code, address, phone } = body;

    if (!name || !code) {
      return Response.json(
        { success: false, error: 'Name and code are required' },
        { status: 400 }
      );
    }

    const { data, error } = await supabase
      .from('schools')
      .insert({
        name,
        name_my: name_my || null,
        code,
        address: address || null,
        phone: phone || null,
        is_active: true,
        settings: {},
      })
      .select()
      .single();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}

export async function PATCH(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, ...updates } = body;

    if (!id) {
      return Response.json({ success: false, error: 'School id is required' }, { status: 400 });
    }

    const allowedFields = ['name', 'name_my', 'code', 'address', 'phone', 'is_active'];
    const safeUpdates: Record<string, unknown> = {};
    for (const key of allowedFields) {
      if (key in updates) {
        safeUpdates[key] = updates[key];
      }
    }

    if (Object.keys(safeUpdates).length === 0) {
      return Response.json({ success: false, error: 'No valid fields to update' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('schools')
      .update(safeUpdates)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
