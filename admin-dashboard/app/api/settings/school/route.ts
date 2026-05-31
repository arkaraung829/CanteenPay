import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const schoolId = request.nextUrl.searchParams.get('school_id');

  if (!schoolId) {
    return Response.json({ success: false, error: 'school_id is required' }, { status: 400 });
  }

  const { data, error } = await supabase
    .from('schools')
    .select('id, name, name_my, code, address, phone, settings')
    .eq('id', schoolId)
    .single();

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  return Response.json({ success: true, data });
}

export async function PUT(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { school_id, name, name_my, address, phone, settings } = body;

    if (!school_id) {
      return Response.json({ success: false, error: 'school_id is required' }, { status: 400 });
    }

    // Build update object for direct school columns
    const updates: Record<string, unknown> = {};
    if (name !== undefined) updates.name = name;
    if (name_my !== undefined) updates.name_my = name_my;
    if (address !== undefined) updates.address = address;
    if (phone !== undefined) updates.phone = phone;
    if (settings !== undefined) updates.settings = settings;

    if (Object.keys(updates).length === 0) {
      return Response.json({ success: false, error: 'No fields to update' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('schools')
      .update(updates)
      .eq('id', school_id)
      .select('id, name, name_my, code, address, phone, settings')
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
