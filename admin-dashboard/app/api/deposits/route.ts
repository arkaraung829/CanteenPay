import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function POST(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { student_id, amount, note } = body;

    if (!student_id || !amount || amount <= 0) {
      return Response.json(
        { success: false, error: 'student_id and a positive amount are required' },
        { status: 400 }
      );
    }

    // Atomic deposit via Postgres function — no race conditions
    const { data, error } = await supabase.rpc('admin_process_deposit', {
      p_student_id: student_id,
      p_amount: amount,
      p_note: note || 'Admin deposit',
    });

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    if (!data.success) {
      return Response.json(
        { success: false, error: data.error },
        { status: 400 }
      );
    }

    return Response.json({
      success: true,
      data: {
        transaction_id: data.transaction_id,
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
