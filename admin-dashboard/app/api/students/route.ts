import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const search = searchParams.get('search') || '';
  const grade = searchParams.get('grade') || '';
  const page = parseInt(searchParams.get('page') || '0');
  const limit = parseInt(searchParams.get('limit') || '50');

  let query = supabase
    .from('students')
    .select('*, wallets(*)', { count: 'exact' })
    .order('full_name')
    .range(page * limit, (page + 1) * limit - 1);

  if (search) {
    query = query.or(`full_name.ilike.%${search}%,student_code.ilike.%${search}%`);
  }

  if (grade) {
    query = query.eq('grade', grade);
  }

  const { data, error, count } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  return Response.json({
    success: true,
    data,
    pagination: {
      page,
      limit,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit),
      hasMore: (page + 1) * limit < (count || 0),
    },
  });
}

export async function POST(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { full_name, full_name_my, grade, class_name, school_id } = body;

    if (!full_name || !school_id) {
      return Response.json(
        { success: false, error: 'full_name and school_id are required' },
        { status: 400 }
      );
    }

    // Generate student code
    const { count } = await supabase
      .from('students')
      .select('id', { count: 'exact', head: true });

    const studentCode = `STU-${new Date().getFullYear()}-${String((count || 0) + 1).padStart(3, '0')}`;

    const { data, error } = await supabase
      .from('students')
      .insert({
        full_name,
        full_name_my: full_name_my || null,
        grade: grade || null,
        class_name: class_name || null,
        student_code: studentCode,
        qr_data: `QR-${studentCode}`,
        school_id,
        is_active: true,
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
