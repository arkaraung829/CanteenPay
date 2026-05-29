import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const search = searchParams.get('search') || '';
  const grade = searchParams.get('grade') || '';
  const className = searchParams.get('class_name') || '';
  const status = searchParams.get('status') || ''; // 'active', 'inactive', or '' (all)
  const schoolId = searchParams.get('school_id') || '';
  const sortBy = searchParams.get('sort_by') || 'full_name';
  const sortDir = searchParams.get('sort_dir') || 'asc';
  const page = parseInt(searchParams.get('page') || '0');
  const limit = parseInt(searchParams.get('limit') || '50');

  // Validate sort parameters
  const allowedSortFields = ['full_name', 'student_code', 'balance', 'grade', 'class_name'];
  const safeSortBy = allowedSortFields.includes(sortBy) ? sortBy : 'full_name';
  const safeSortDir = sortDir === 'desc' ? false : true; // ascending = true

  // For balance sorting, we need to sort after fetching since balance is in wallets table
  const isSortByBalance = safeSortBy === 'balance';

  let query = supabase
    .from('students')
    .select('id, student_code, full_name, full_name_my, class_name, grade, is_active, daily_spending_limit, parent_phone, wallets(balance), parent_student_links(profiles!parent_student_links_parent_id_fkey(full_name))', { count: 'exact' });

  // Apply sort (not for balance - handled client-side after fetch)
  if (!isSortByBalance) {
    query = query.order(safeSortBy, { ascending: safeSortDir });
  } else {
    query = query.order('full_name', { ascending: true });
  }

  if (schoolId) {
    query = query.eq('school_id', schoolId);
  }

  if (search) {
    query = query.or(`full_name.ilike.%${search}%,student_code.ilike.%${search}%`);
  }

  if (grade) {
    query = query.eq('grade', grade);
  }

  if (className) {
    query = query.eq('class_name', className);
  }

  if (status === 'active') {
    query = query.eq('is_active', true);
  } else if (status === 'inactive') {
    query = query.eq('is_active', false);
  }

  // Apply pagination
  query = query.range(page * limit, (page + 1) * limit - 1);

  const { data, error, count } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  // Map wallet balance and parent name into each student row
  const mapped = (data || []).map((s: Record<string, unknown>) => {
    const wallets = s.wallets as Array<{ balance: number }> | { balance: number } | null;
    let balance = 0;
    if (Array.isArray(wallets) && wallets.length > 0) {
      balance = wallets[0].balance || 0;
    } else if (wallets && !Array.isArray(wallets)) {
      balance = wallets.balance || 0;
    }

    // Extract parent name from linked parents
    let parentName: string | null = null;
    const links = s.parent_student_links as Array<{ profiles: { full_name: string } | null }> | null;
    if (Array.isArray(links) && links.length > 0 && links[0].profiles) {
      parentName = links[0].profiles.full_name;
    }

    return {
      id: s.id,
      student_code: s.student_code,
      full_name: s.full_name,
      full_name_my: s.full_name_my,
      class_name: s.class_name,
      grade: s.grade,
      is_active: s.is_active,
      daily_spending_limit: s.daily_spending_limit,
      balance,
      parent_name: parentName,
    };
  });

  // Sort by balance if requested (server-side sort not possible for joined field)
  if (isSortByBalance) {
    mapped.sort((a: { balance: number }, b: { balance: number }) =>
      safeSortDir ? a.balance - b.balance : b.balance - a.balance
    );
  }

  // Also fetch grade and class lists for filter dropdowns
  let gradeQuery = supabase
    .from('students')
    .select('grade')
    .not('grade', 'is', null)
    .order('grade');

  let classQuery = supabase
    .from('students')
    .select('class_name')
    .not('class_name', 'is', null)
    .order('class_name');

  let activeQuery = supabase
    .from('students')
    .select('id', { count: 'exact', head: true })
    .eq('is_active', true);

  let inactiveQuery = supabase
    .from('students')
    .select('id', { count: 'exact', head: true })
    .eq('is_active', false);

  if (schoolId) {
    gradeQuery = gradeQuery.eq('school_id', schoolId);
    classQuery = classQuery.eq('school_id', schoolId);
    activeQuery = activeQuery.eq('school_id', schoolId);
    inactiveQuery = inactiveQuery.eq('school_id', schoolId);
  }

  const { data: gradeData } = await gradeQuery;
  const { data: classData } = await classQuery;

  const grades = [...new Set((gradeData || []).map((r: { grade: string }) => r.grade))];
  const classes = [...new Set((classData || []).map((r: { class_name: string }) => r.class_name))];

  // Fetch active/inactive counts
  const { count: activeCount } = await activeQuery;
  const { count: inactiveCount } = await inactiveQuery;

  return Response.json({
    success: true,
    data: mapped,
    grades,
    classes,
    stats: {
      active: activeCount || 0,
      inactive: inactiveCount || 0,
    },
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
    const { full_name, full_name_my, grade, class_name, parent_phone, date_of_birth } = body;
    let { school_id } = body;

    if (!full_name) {
      return Response.json(
        { success: false, error: 'full_name is required' },
        { status: 400 }
      );
    }

    // Auto-assign school_id if not provided
    if (!school_id) {
      const { data: schools } = await supabase
        .from('schools')
        .select('id')
        .eq('is_active', true)
        .limit(1);
      school_id = schools?.[0]?.id;
      if (!school_id) {
        return Response.json(
          { success: false, error: 'No school found. Please create a school first.' },
          { status: 400 }
        );
      }
    }

    // Generate student code
    const { count } = await supabase
      .from('students')
      .select('id', { count: 'exact', head: true });

    const studentCode = `STU-${new Date().getFullYear()}-${String((count || 0) + 1).padStart(3, '0')}`;

    // Generate unique 4-digit PIN within this school
    let pinCode = '';
    for (let i = 0; i < 10; i++) {
      const candidate = String(Math.floor(Math.random() * 10000)).padStart(4, '0');
      const { data: existing } = await supabase
        .from('students')
        .select('id')
        .eq('school_id', school_id)
        .eq('pin_code', candidate)
        .limit(1);
      if (!existing || existing.length === 0) {
        pinCode = candidate;
        break;
      }
    }
    if (!pinCode) {
      pinCode = String(Math.floor(Math.random() * 10000)).padStart(4, '0');
    }

    // Normalize parent phone: strip leading 0, ensure +95 prefix
    let normalizedPhone: string | null = null;
    if (parent_phone) {
      let ph = parent_phone.replace(/\s+/g, '');
      if (ph.startsWith('0')) {
        ph = '+95' + ph.substring(1);
      } else if (!ph.startsWith('+')) {
        ph = '+' + ph;
      }
      normalizedPhone = ph;
    }

    const { data, error } = await supabase
      .from('students')
      .insert({
        full_name,
        full_name_my: full_name_my || null,
        grade: grade || null,
        class_name: class_name || null,
        student_code: studentCode,
        qr_data: crypto.randomUUID(),
        pin_code: pinCode,
        school_id,
        is_active: true,
        parent_phone: normalizedPhone,
        date_of_birth: date_of_birth || null,
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
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, ...updates } = body;

    if (!id) {
      return Response.json({ success: false, error: 'Student id is required' }, { status: 400 });
    }

    // Only allow specific fields to be updated
    const allowedFields = ['full_name', 'full_name_my', 'grade', 'class_name', 'is_active', 'daily_spending_limit', 'parent_phone', 'parent_email', 'date_of_birth'];
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
      .from('students')
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
