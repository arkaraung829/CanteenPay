import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const { data, error } = await supabase.rpc('reconcile_wallets');

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return Response.json({
      success: true,
      healthy: !data || data.length === 0,
      discrepancies: data || [],
      checked_at: new Date().toISOString(),
    });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Unknown error' },
      { status: 500 }
    );
  }
}
