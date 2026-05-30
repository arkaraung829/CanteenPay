import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const schoolId = request.nextUrl.searchParams.get('school_id') || '';

  let query = supabase
    .from('school_sections')
    .select('*')
    .order('display_order', { ascending: true });

  if (schoolId) {
    query = query.eq('school_id', schoolId);
  }

  const { data, error } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  return Response.json({ success: true, data: data || [] });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { name } = body;
    let { school_id } = body;

    if (!name || !name.trim()) {
      return Response.json({ success: false, error: 'Name is required' }, { status: 400 });
    }

    // Get the school_id if not provided
    if (!school_id) {
      const { data: schools } = await supabase
        .from('schools')
        .select('id')
        .eq('is_active', true)
        .limit(1);

      school_id = schools?.[0]?.id;
    }
    if (!school_id) {
      return Response.json({ success: false, error: 'No school found' }, { status: 400 });
    }

    // Get max display_order
    const { data: maxOrder } = await supabase
      .from('school_sections')
      .select('display_order')
      .eq('school_id', school_id)
      .order('display_order', { ascending: false })
      .limit(1);

    const nextOrder = (maxOrder?.[0]?.display_order ?? -1) + 1;

    const { data, error } = await supabase
      .from('school_sections')
      .insert({
        school_id,
        name: name.trim(),
        display_order: nextOrder,
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

export async function PATCH(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, ...updates } = body;

    if (!id) {
      return Response.json({ success: false, error: 'ID is required' }, { status: 400 });
    }

    const allowedFields = ['name', 'display_order', 'is_active'];
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
      .from('school_sections')
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

export async function DELETE(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id } = body;

    if (!id) {
      return Response.json({ success: false, error: 'ID is required' }, { status: 400 });
    }

    const { error } = await supabase
      .from('school_sections')
      .delete()
      .eq('id', id);

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return Response.json({ success: true });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
