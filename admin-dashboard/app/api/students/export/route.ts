import { createAdminClient } from '@/lib/supabase';

export async function GET() {
  const supabase = createAdminClient();

  // Fetch all students with wallet balance
  const { data, error } = await supabase
    .from('students')
    .select('student_code, full_name, grade, class_name, is_active, wallets(balance)')
    .order('full_name');

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  // Build CSV
  const headers = ['student_code', 'full_name', 'grade', 'class_name', 'balance', 'status'];
  const rows = (data || []).map((s: Record<string, unknown>) => {
    const wallets = s.wallets as Array<{ balance: number }> | { balance: number } | null;
    let balance = 0;
    if (Array.isArray(wallets) && wallets.length > 0) {
      balance = wallets[0].balance || 0;
    } else if (wallets && !Array.isArray(wallets)) {
      balance = wallets.balance || 0;
    }

    return [
      s.student_code,
      `"${(s.full_name as string || '').replace(/"/g, '""')}"`,
      s.grade || '',
      `"${((s.class_name as string) || '').replace(/"/g, '""')}"`,
      balance,
      s.is_active ? 'Active' : 'Inactive',
    ].join(',');
  });

  const csv = [headers.join(','), ...rows].join('\n');

  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="students-export-${new Date().toISOString().split('T')[0]}.csv"`,
    },
  });
}
