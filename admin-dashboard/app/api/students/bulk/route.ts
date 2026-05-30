import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { action, studentIds } = body as { action: string; studentIds: string[] };

    if (!action || !Array.isArray(studentIds) || studentIds.length === 0) {
      return Response.json(
        { success: false, error: 'action and studentIds[] are required' },
        { status: 400 }
      );
    }

    if (!['activate', 'deactivate', 'delete'].includes(action)) {
      return Response.json(
        { success: false, error: 'Invalid action. Use: activate, deactivate, delete' },
        { status: 400 }
      );
    }

    let error;

    if (action === 'activate') {
      ({ error } = await supabase
        .from('students')
        .update({ is_active: true })
        .in('id', studentIds));
    } else if (action === 'deactivate') {
      ({ error } = await supabase
        .from('students')
        .update({ is_active: false })
        .in('id', studentIds));
    } else if (action === 'delete') {
      ({ error } = await supabase
        .from('students')
        .delete()
        .in('id', studentIds));
    }

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return Response.json({
      success: true,
      message: `${action} applied to ${studentIds.length} student(s)`,
    });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
