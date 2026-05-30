import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  // Get the school_id
  const { data: schools } = await supabase
    .from('schools')
    .select('id')
    .eq('is_active', true)
    .limit(1);

  const school_id = schools?.[0]?.id;
  if (!school_id) {
    return Response.json({ success: false, error: 'No school found' }, { status: 400 });
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('id, role, full_name, full_name_my, phone, is_active, created_at')
    .eq('school_id', school_id)
    .in('role', ['admin', 'counter_staff', 'seller'])
    .order('created_at', { ascending: false });

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  // Get emails from Supabase Auth for each user
  const usersWithEmail = await Promise.all(
    (data || []).map(async (profile) => {
      const { data: authUser } = await supabase.auth.admin.getUserById(profile.id);
      return {
        ...profile,
        email: authUser?.user?.email || '',
      };
    })
  );

  return Response.json({ success: true, data: usersWithEmail });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { email, password, full_name, role } = body;

    if (!email || !password || !full_name || !role) {
      return Response.json(
        { success: false, error: 'Email, password, full name, and role are required' },
        { status: 400 }
      );
    }

    const allowedRoles = ['admin', 'counter_staff', 'seller'];
    if (!allowedRoles.includes(role)) {
      return Response.json(
        { success: false, error: `Role must be one of: ${allowedRoles.join(', ')}` },
        { status: 400 }
      );
    }

    // Get school_id
    const { data: schools } = await supabase
      .from('schools')
      .select('id')
      .eq('is_active', true)
      .limit(1);

    const school_id = schools?.[0]?.id;
    if (!school_id) {
      return Response.json({ success: false, error: 'No school found' }, { status: 400 });
    }

    // Create auth user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError) {
      return Response.json({ success: false, error: authError.message }, { status: 500 });
    }

    // Upsert profile
    const { error: profileError } = await supabase
      .from('profiles')
      .upsert({
        id: authData.user.id,
        role,
        school_id,
        full_name,
        is_active: true,
        locale: 'en',
      });

    if (profileError) {
      // Clean up auth user if profile creation fails
      await supabase.auth.admin.deleteUser(authData.user.id);
      return Response.json({ success: false, error: profileError.message }, { status: 500 });
    }

    return Response.json({ success: true, data: { id: authData.user.id } });
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

    // Handle password update via auth admin
    if (updates.password) {
      const { error: authError } = await supabase.auth.admin.updateUserById(id, {
        password: updates.password,
      });
      if (authError) {
        return Response.json({ success: false, error: authError.message }, { status: 500 });
      }
    }

    // Handle email update via auth admin
    if (updates.email) {
      const { error: authError } = await supabase.auth.admin.updateUserById(id, {
        email: updates.email,
        email_confirm: true,
      });
      if (authError) {
        return Response.json({ success: false, error: authError.message }, { status: 500 });
      }
    }

    // Handle profile field updates
    const allowedFields = ['full_name', 'role', 'is_active', 'phone'];
    const safeUpdates: Record<string, unknown> = {};
    for (const key of allowedFields) {
      if (key in updates) {
        safeUpdates[key] = updates[key];
      }
    }

    if (Object.keys(safeUpdates).length > 0) {
      const { error } = await supabase
        .from('profiles')
        .update(safeUpdates)
        .eq('id', id);

      if (error) {
        return Response.json({ success: false, error: error.message }, { status: 500 });
      }
    }

    return Response.json({ success: true });
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

    // Delete auth user (cascades to profile if FK set up)
    const { error: authError } = await supabase.auth.admin.deleteUser(id);
    if (authError) {
      return Response.json({ success: false, error: authError.message }, { status: 500 });
    }

    // Also delete profile explicitly in case no cascade
    await supabase.from('profiles').delete().eq('id', id);

    return Response.json({ success: true });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
