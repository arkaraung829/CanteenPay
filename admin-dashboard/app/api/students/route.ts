import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

// Cache filter data for 30 seconds (grades, classes, counts don't change often)
let filterCache: { data: unknown; schoolId: string; ts: number } | null = null;
const CACHE_TTL = 30_000;

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const search = searchParams.get('search') || '';
  const grade = searchParams.get('grade') || '';
  const className = searchParams.get('class_name') || '';
  const status = searchParams.get('status') || '';
  const schoolId = searchParams.get('school_id') || '';
  const sortBy = searchParams.get('sort_by') || 'full_name';
  const sortDir = searchParams.get('sort_dir') || 'asc';
  const page = parseInt(searchParams.get('page') || '0');
  const limit = parseInt(searchParams.get('limit') || '50');

  const allowedSortFields = ['full_name', 'student_code', 'balance', 'grade', 'class_name'];
  const safeSortBy = allowedSortFields.includes(sortBy) ? sortBy : 'full_name';
  const safeSortDir = sortDir !== 'desc';
  const isSortByBalance = safeSortBy === 'balance';

  // Build main query
  let query = supabase
    .from('students')
    .select('id, student_code, full_name, full_name_my, class_name, grade, is_active, daily_spending_limit, parent_phone, wallets(balance)', { count: 'exact' });

  if (!isSortByBalance) {
    query = query.order(safeSortBy, { ascending: safeSortDir });
  } else {
    query = query.order('full_name', { ascending: true });
  }

  if (schoolId) query = query.eq('school_id', schoolId);
  if (search) query = query.or(`full_name.ilike.%${search}%,student_code.ilike.%${search}%`);
  if (grade) query = query.eq('grade', grade);
  if (className) query = query.eq('class_name', className);
  if (status === 'active') query = query.eq('is_active', true);
  else if (status === 'inactive') query = query.eq('is_active', false);

  query = query.range(page * limit, (page + 1) * limit - 1);

  // Check filter cache
  const useCache = filterCache && filterCache.schoolId === schoolId && (Date.now() - filterCache.ts) < CACHE_TTL;

  // Run main query + filter queries in parallel
  const [mainResult, filterResult] = await Promise.all([
    query,
    useCache
      ? Promise.resolve(filterCache!.data)
      : (async () => {
          const filterBase = schoolId ? { school_id: schoolId } : {};
          const [g, c, a, i] = await Promise.all([
            supabase.from('students').select('grade').not('grade', 'is', null).match(filterBase).order('grade'),
            supabase.from('students').select('class_name').not('class_name', 'is', null).match(filterBase).order('class_name'),
            supabase.from('students').select('id', { count: 'exact', head: true }).eq('is_active', true).match(filterBase),
            supabase.from('students').select('id', { count: 'exact', head: true }).eq('is_active', false).match(filterBase),
          ]);
          const result = {
            grades: [...new Set((g.data || []).map((r: { grade: string }) => r.grade))],
            classes: [...new Set((c.data || []).map((r: { class_name: string }) => r.class_name))],
            stats: { active: a.count || 0, inactive: i.count || 0 },
          };
          filterCache = { data: result, schoolId, ts: Date.now() };
          return result;
        })(),
  ]);

  const { data, error, count } = mainResult;
  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  const filters = filterResult as { grades: string[]; classes: string[]; stats: { active: number; inactive: number } };

  // Map wallet balance
  const mapped = (data || []).map((s: Record<string, unknown>) => {
    const wallets = s.wallets as Array<{ balance: number }> | { balance: number } | null;
    let balance = 0;
    if (Array.isArray(wallets) && wallets.length > 0) balance = wallets[0].balance || 0;
    else if (wallets && !Array.isArray(wallets)) balance = (wallets as { balance: number }).balance || 0;

    return {
      id: s.id, student_code: s.student_code, full_name: s.full_name, full_name_my: s.full_name_my,
      class_name: s.class_name, grade: s.grade, is_active: s.is_active,
      daily_spending_limit: s.daily_spending_limit, balance,
      parent_name: (s.parent_phone as string) || null,
    };
  });

  if (isSortByBalance) {
    mapped.sort((a: { balance: number }, b: { balance: number }) =>
      safeSortDir ? a.balance - b.balance : b.balance - a.balance
    );
  }

  return NextResponse.json({
    success: true,
    data: mapped,
    grades: filters.grades,
    classes: filters.classes,
    stats: filters.stats,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit), hasMore: (page + 1) * limit < (count || 0) },
  }, {
    headers: { 'Cache-Control': 'private, max-age=5' },
  });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { full_name, full_name_my, grade, class_name, parent_phone, date_of_birth } = body;
    let { school_id } = body;

    if (!full_name) {
      return Response.json({ success: false, error: 'full_name is required' }, { status: 400 });
    }

    if (!school_id) {
      const { data: schools } = await supabase.from('schools').select('id').eq('is_active', true).limit(1);
      school_id = schools?.[0]?.id;
      if (!school_id) {
        return Response.json({ success: false, error: 'No school found.' }, { status: 400 });
      }
    }

    const { count } = await supabase.from('students').select('id', { count: 'exact', head: true });
    const studentCode = `STU-${new Date().getFullYear()}-${String((count || 0) + 1).padStart(3, '0')}`;

    // Generate unique 4-digit PIN
    let pinCode = '';
    for (let i = 0; i < 10; i++) {
      const candidate = String(Math.floor(Math.random() * 10000)).padStart(4, '0');
      const { data: existing } = await supabase.from('students').select('id').eq('school_id', school_id).eq('pin_code', candidate).limit(1);
      if (!existing || existing.length === 0) { pinCode = candidate; break; }
    }
    if (!pinCode) pinCode = String(Math.floor(Math.random() * 10000)).padStart(4, '0');

    let normalizedPhone: string | null = null;
    if (parent_phone) {
      let ph = parent_phone.replace(/\s+/g, '');
      if (ph.startsWith('0')) ph = '+95' + ph.substring(1);
      else if (!ph.startsWith('+')) ph = '+' + ph;
      normalizedPhone = ph;
    }

    const { data, error } = await supabase.from('students').insert({
      full_name, full_name_my: full_name_my || null, grade: grade || null,
      class_name: class_name || null, student_code: studentCode,
      qr_data: crypto.randomUUID(), pin_code: pinCode, school_id,
      is_active: true, parent_phone: normalizedPhone, date_of_birth: date_of_birth || null,
    }).select().single();

    if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

    // Invalidate filter cache
    filterCache = null;

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json({ success: false, error: err instanceof Error ? err.message : 'Invalid request' }, { status: 400 });
  }
}

export async function PATCH(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, ...updates } = body;

    if (!id) return Response.json({ success: false, error: 'Student id is required' }, { status: 400 });

    const allowedFields = ['full_name', 'full_name_my', 'grade', 'class_name', 'is_active', 'daily_spending_limit', 'parent_phone', 'parent_email', 'date_of_birth', 'pin_code'];
    const safeUpdates: Record<string, unknown> = {};
    for (const key of allowedFields) {
      if (key in updates) safeUpdates[key] = updates[key];
    }

    if (Object.keys(safeUpdates).length === 0) {
      return Response.json({ success: false, error: 'No valid fields to update' }, { status: 400 });
    }

    const { data, error } = await supabase.from('students').update(safeUpdates).eq('id', id).select().single();
    if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

    // Invalidate filter cache on status change
    if ('is_active' in safeUpdates) filterCache = null;

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json({ success: false, error: err instanceof Error ? err.message : 'Invalid request' }, { status: 400 });
  }
}
