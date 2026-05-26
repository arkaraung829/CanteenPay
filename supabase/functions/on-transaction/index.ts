// Supabase Edge Function: on-transaction
// Triggered by database webhook on INSERT into transactions table
// Sends push notification to parent's device when a purchase is made

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const fcmServerKey = Deno.env.get('FCM_SERVER_KEY');

interface Transaction {
  id: string;
  wallet_id: string;
  type: 'deposit' | 'purchase' | 'refund' | 'adjustment';
  amount: number;
  balance_after: number;
  description?: string;
  seller_id?: string;
}

interface WebhookPayload {
  type: 'INSERT';
  table: string;
  record: Transaction;
  schema: string;
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const transaction = payload.record;

    // Only notify on purchases (not deposits/refunds - those are done by staff who sees it)
    if (transaction.type !== 'purchase') {
      return new Response(JSON.stringify({ message: 'Skipped: not a purchase' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get wallet → student → linked parents with FCM tokens
    const { data: wallet } = await supabase
      .from('wallets')
      .select('student_id')
      .eq('id', transaction.wallet_id)
      .single();

    if (!wallet) {
      return new Response(JSON.stringify({ error: 'Wallet not found' }), { status: 404 });
    }

    // Get student name
    const { data: student } = await supabase
      .from('students')
      .select('full_name')
      .eq('id', wallet.student_id)
      .single();

    // Get seller stall name
    let sellerName = 'Canteen';
    if (transaction.seller_id) {
      const { data: seller } = await supabase
        .from('canteen_sellers')
        .select('stall_name')
        .eq('id', transaction.seller_id)
        .single();
      if (seller) sellerName = seller.stall_name;
    }

    // Get linked parents' FCM tokens
    const { data: links } = await supabase
      .from('parent_student_links')
      .select('parent_id')
      .eq('student_id', wallet.student_id);

    if (!links || links.length === 0) {
      return new Response(JSON.stringify({ message: 'No linked parents' }), { status: 200 });
    }

    const parentIds = links.map((l: { parent_id: string }) => l.parent_id);
    const { data: parents } = await supabase
      .from('profiles')
      .select('fcm_token')
      .in('id', parentIds)
      .not('fcm_token', 'is', null);

    if (!parents || parents.length === 0) {
      return new Response(JSON.stringify({ message: 'No FCM tokens found' }), { status: 200 });
    }

    // Format notification
    const formattedAmount = transaction.amount.toLocaleString();
    const formattedBalance = transaction.balance_after.toLocaleString();
    const title = `Purchase: ${formattedAmount} MMK`;
    const body = `${student?.full_name || 'Student'} spent ${formattedAmount} MMK at ${sellerName}. Balance: ${formattedBalance} MMK`;

    // Send FCM notifications
    if (fcmServerKey) {
      const tokens = parents
        .map((p: { fcm_token: string }) => p.fcm_token)
        .filter(Boolean);

      if (tokens.length > 0) {
        const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `key=${fcmServerKey}`,
          },
          body: JSON.stringify({
            registration_ids: tokens,
            notification: { title, body },
            data: {
              type: 'purchase',
              transaction_id: transaction.id,
              student_id: wallet.student_id,
              amount: transaction.amount.toString(),
              balance_after: transaction.balance_after.toString(),
            },
          }),
        });

        const fcmResult = await fcmResponse.json();
        return new Response(JSON.stringify({ success: true, fcm: fcmResult }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    return new Response(JSON.stringify({ success: true, message: 'Notification prepared (FCM key not set)' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
