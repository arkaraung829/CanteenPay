import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const type = searchParams.get('type') || '';
  const date = searchParams.get('date') || '';
  const page = parseInt(searchParams.get('page') || '0');
  const limit = parseInt(searchParams.get('limit') || '20');

  let query = supabase
    .from('transactions')
    .select(`
      id,
      type,
      amount,
      balance_before,
      balance_after,
      description,
      created_at,
      performed_by,
      seller_id,
      wallet:wallets(
        id,
        student:students(id, full_name, student_code)
      )
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * limit, (page + 1) * limit - 1);

  if (type && type !== 'all') {
    query = query.eq('type', type);
  }

  if (date) {
    query = query.gte('created_at', `${date}T00:00:00`).lte('created_at', `${date}T23:59:59`);
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
