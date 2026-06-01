import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

// GET: list refund requests
export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const status = searchParams.get('status') || '';

  let query = supabase
    .from('refund_requests')
    .select('*, students(full_name, student_code), canteen_sellers!refund_requests_seller_id_fkey(stall_name)')
    .order('created_at', { ascending: false });

  if (status) query = query.eq('status', status);

  const { data, error } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  return Response.json({ success: true, data: data || [] });
}

// POST: create a refund request (pending seller approval)
export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

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

    // Get the original transaction to find student and seller
    const { data: tx, error: txError } = await supabase
      .from('transactions')
      .select('id, wallet_id, amount, seller_id, type')
      .eq('id', transaction_id)
      .single();

    if (txError || !tx) {
      return Response.json({ success: false, error: 'Transaction not found' }, { status: 404 });
    }

    if (tx.type !== 'purchase') {
      return Response.json({ success: false, error: 'Can only refund purchases' }, { status: 400 });
    }

    // Get student from wallet
    const { data: wallet } = await supabase
      .from('wallets')
      .select('student_id')
      .eq('id', tx.wallet_id)
      .single();

    if (!wallet) {
      return Response.json({ success: false, error: 'Wallet not found' }, { status: 404 });
    }

    // Check for existing refund request (unique constraint on transaction_id)
    const { data: existing } = await supabase
      .from('refund_requests')
      .select('id, status')
      .eq('transaction_id', transaction_id)
      .maybeSingle();

    if (existing) {
      return Response.json({ success: false, error: `A refund request already exists for this transaction (status: ${existing.status})` }, { status: 400 });
    }

    // If no seller (e.g. admin-created purchase), process refund directly
    if (!tx.seller_id) {
      const { data: refundData, error: refundError } = await supabase.rpc('admin_process_refund', {
        p_transaction_id: transaction_id,
        p_reason: reason || 'Admin refund',
      });

      if (refundError) {
        return Response.json({ success: false, error: refundError.message }, { status: 500 });
      }

      return Response.json({ success: true, data: refundData, direct: true });
    }

    // Create refund request for seller approval
    const { data: req, error: reqError } = await supabase
      .from('refund_requests')
      .insert({
        transaction_id,
        student_id: wallet.student_id,
        seller_id: tx.seller_id,
        amount: tx.amount,
        reason: reason || null,
        requested_by: auth.userId,
        status: 'pending',
      })
      .select()
      .single();

    if (reqError) {
      return Response.json({ success: false, error: reqError.message }, { status: 500 });
    }

    // Send push notification to seller
    try {
      const { data: seller } = await supabase
        .from('canteen_sellers')
        .select('profile_id')
        .eq('id', tx.seller_id)
        .single();

      if (seller?.profile_id) {
        const { data: sellerProfile } = await supabase
          .from('profiles')
          .select('fcm_token')
          .eq('id', seller.profile_id)
          .not('fcm_token', 'is', null)
          .single();

        if (sellerProfile?.fcm_token) {
          const { data: student } = await supabase
            .from('students')
            .select('full_name')
            .eq('id', wallet.student_id)
            .single();

          // Send via edge function or direct FCM
          const fcmSA = process.env.FCM_SERVICE_ACCOUNT;
          if (fcmSA) {
            const sa = JSON.parse(fcmSA);
            const crypto = await import('crypto');
            function b64url(buf: Buffer | Uint8Array): string { return Buffer.from(buf).toString('base64url'); }
            const now = Math.floor(Date.now() / 1000);
            const header = b64url(Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
            const claims = b64url(Buffer.from(JSON.stringify({ iss: sa.client_email, sub: sa.client_email, aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600, scope: 'https://www.googleapis.com/auth/firebase.messaging' })));
            const si = `${header}.${claims}`;
            const sign = crypto.createSign('RSA-SHA256'); sign.update(si);
            const jwt = `${si}.${b64url(sign.sign(sa.private_key))}`;
            const tokenRes = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }) });
            const tokenData = await tokenRes.json();
            if (tokenData.access_token) {
              await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenData.access_token}` },
                body: JSON.stringify({ message: { token: sellerProfile.fcm_token, notification: { title: 'Refund Request', body: `Refund ${tx.amount.toLocaleString()} MMK for ${student?.full_name || 'student'}. Please approve or reject.` }, data: { type: 'refund_request', request_id: req.id }, android: { priority: 'high' }, apns: { payload: { aps: { sound: 'default', badge: 1 } } } } }),
              });
            }
          }
        }
      }
    } catch {
      // Push notification failure shouldn't fail the request
    }

    return Response.json({ success: true, data: req, pending: true });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
