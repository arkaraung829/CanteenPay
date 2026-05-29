import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function POST(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { student_id, amount, staff_profile_id, payment_method, note } = body;

    if (!student_id || !amount || amount <= 0) {
      return Response.json(
        { success: false, error: 'student_id and a positive amount are required' },
        { status: 400 }
      );
    }

    // Get wallet
    const { data: wallet, error: walletError } = await supabase
      .from('wallets')
      .select('id, balance')
      .eq('student_id', student_id)
      .single();

    if (walletError || !wallet) {
      return Response.json(
        { success: false, error: 'Student wallet not found' },
        { status: 404 }
      );
    }

    const newBalance = wallet.balance + amount;

    // Update wallet balance
    const { error: updateError } = await supabase
      .from('wallets')
      .update({ balance: newBalance })
      .eq('id', wallet.id);

    if (updateError) {
      return Response.json({ success: false, error: updateError.message }, { status: 500 });
    }

    // Create transaction record
    const { data: txData, error: txError } = await supabase
      .from('transactions')
      .insert({
        wallet_id: wallet.id,
        type: 'deposit',
        amount,
        balance_before: wallet.balance,
        balance_after: newBalance,
        description: note || `Cash deposit (${payment_method || 'cash'})`,
        performed_by: staff_profile_id || null,
        metadata: { payment_method: payment_method || 'cash' },
      })
      .select()
      .single();

    if (txError) {
      // Rollback wallet
      await supabase.from('wallets').update({ balance: wallet.balance }).eq('id', wallet.id);
      return Response.json({ success: false, error: txError.message }, { status: 500 });
    }

    return Response.json({
      success: true,
      data: {
        transaction_id: txData.id,
        new_balance: newBalance,
        reference_id: txData.id,
      },
    });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
