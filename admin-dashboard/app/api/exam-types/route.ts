import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, verifyAdminOrTeacher, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const schoolId = searchParams.get('school_id') || '';

  let query = supabase
    .from('exam_types')
    .select('*')
    .order('display_order', { ascending: true })
    .order('name', { ascending: true });

  if (schoolId) query = query.eq('school_id', schoolId);

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
    const { name, name_my, weight, term, school_id } = body;

    if (!name) {
      return Response.json({ success: false, error: 'name is required' }, { status: 400 });
    }

    let resolvedSchoolId = school_id;
    if (!resolvedSchoolId) {
      const { data: schools } = await supabase.from('schools').select('id').eq('is_active', true).limit(1);
      resolvedSchoolId = schools?.[0]?.id;
      if (!resolvedSchoolId) {
        return Response.json({ success: false, error: 'No school found' }, { status: 400 });
      }
    }

    // Get max display_order
    const { data: maxOrder } = await supabase
      .from('exam_types')
      .select('display_order')
      .eq('school_id', resolvedSchoolId)
      .order('display_order', { ascending: false })
      .limit(1);

    const nextOrder = (maxOrder?.[0]?.display_order ?? -1) + 1;

    const { data, error } = await supabase
      .from('exam_types')
      .insert({
        school_id: resolvedSchoolId,
        name,
        name_my: name_my || null,
        weight: weight ?? 100,
        term: term || null,
        display_order: nextOrder,
      })
      .select()
      .single();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data });
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

    if (!id) return Response.json({ success: false, error: 'id is required' }, { status: 400 });

    const allowedFields = ['name', 'name_my', 'weight', 'term', 'display_order', 'is_active'];
    const safeUpdates: Record<string, unknown> = {};
    for (const key of allowedFields) {
      if (key in updates) safeUpdates[key] = updates[key];
    }

    if (Object.keys(safeUpdates).length === 0) {
      return Response.json({ success: false, error: 'No valid fields to update' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('exam_types')
      .update(safeUpdates)
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

export async function DELETE(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id } = body;

    if (!id) return Response.json({ success: false, error: 'id is required' }, { status: 400 });

    const { error } = await supabase.from('exam_types').delete().eq('id', id);

    if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

    return NextResponse.json({ success: true });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
