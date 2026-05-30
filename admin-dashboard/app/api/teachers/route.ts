import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const schoolId = searchParams.get('school_id') || '';

  let query = supabase
    .from('teachers')
    .select('*')
    .order('full_name', { ascending: true });

  if (schoolId) {
    query = query.eq('school_id', schoolId);
  }

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
    const { full_name, email, phone, school_id, assigned_grades, assigned_classes, password } = body;

    if (!full_name || !email || !school_id) {
      return Response.json(
        { success: false, error: 'full_name, email, and school_id are required' },
        { status: 400 }
      );
    }

    const teacherPassword = password || 'Teacher@123';

    // 1. Create Supabase auth user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: email.toLowerCase(),
      password: teacherPassword,
      email_confirm: true,
    });

    if (authError) {
      return Response.json({ success: false, error: authError.message }, { status: 400 });
    }

    const userId = authData.user.id;

    // 2. Create profile with teacher role
    const { error: profileError } = await supabase
      .from('profiles')
      .upsert({
        id: userId,
        full_name,
        role: 'teacher',
        school_id,
        phone: phone || null,
      });

    if (profileError) {
      // Cleanup: delete auth user if profile creation fails
      await supabase.auth.admin.deleteUser(userId);
      return Response.json({ success: false, error: profileError.message }, { status: 500 });
    }

    // 3. Create teachers record
    const { data: teacherData, error: teacherError } = await supabase
      .from('teachers')
      .insert({
        profile_id: userId,
        school_id,
        full_name,
        email: email.toLowerCase(),
        phone: phone || null,
        assigned_grades: assigned_grades || [],
        assigned_classes: assigned_classes || [],
        is_active: true,
      })
      .select()
      .single();

    if (teacherError) {
      return Response.json({ success: false, error: teacherError.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data: teacherData });
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

    const allowedFields = ['full_name', 'email', 'phone', 'assigned_grades', 'assigned_classes', 'is_active'];
    const safeUpdates: Record<string, unknown> = {};
    for (const key of allowedFields) {
      if (key in updates) {
        safeUpdates[key] = updates[key];
      }
    }
    safeUpdates['updated_at'] = new Date().toISOString();

    if (Object.keys(safeUpdates).length <= 1) {
      return Response.json({ success: false, error: 'No valid fields to update' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('teachers')
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

    // Deactivate rather than hard delete
    const { error } = await supabase
      .from('teachers')
      .update({ is_active: false, updated_at: new Date().toISOString() })
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
