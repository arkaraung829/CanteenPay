import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function POST(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { transaction_id, reason } = body;

    if (!transaction_id) {
      return Response.json(
        { success: false, error: 'transaction_id is required' },
        { status: 400 }
      );
    }

    const { data, error } = await supabase.rpc('admin_process_refund', {
      p_transaction_id: transaction_id,
      p_reason: reason || 'Admin refund',
    });

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    if (!data.success) {
      return Response.json({ success: false, error: data.error }, { status: 400 });
    }

    return Response.json({
      success: true,
      data: {
        transaction_id: data.transaction_id,
        student_name: data.student_name,
        amount: data.amount,
        new_balance: data.new_balance,
      },
    });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
