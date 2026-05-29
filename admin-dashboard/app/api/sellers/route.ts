import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function PATCH(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, ...updates } = body;

    if (!id) {
      return Response.json({ success: false, error: 'ID is required' }, { status: 400 });
    }

    const allowedFields = ['stall_name', 'stall_number', 'phone', 'email', 'is_active'];
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
      .from('canteen_sellers')
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
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id } = body;

    if (!id) {
      return Response.json({ success: false, error: 'ID is required' }, { status: 400 });
    }

    const { error } = await supabase
      .from('canteen_sellers')
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
