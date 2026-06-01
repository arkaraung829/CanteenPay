import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

// GET: list payout requests
export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const status = request.nextUrl.searchParams.get('status') || '';

  let query = supabase
    .from('seller_payouts')
    .select('*, canteen_sellers(stall_name, profiles(full_name))')
    .order('requested_at', { ascending: false });

  if (status) query = query.eq('status', status);

  const { data, error } = await query;
  if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

  return Response.json({ success: true, data: data || [] });
}

// POST: seller creates payout request
export async function POST(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { seller_id, amount, notes } = body;

    if (!seller_id || !amount || amount <= 0) {
      return Response.json({ success: false, error: 'seller_id and positive amount required' }, { status: 400 });
    }

    // Check available balance
    const { data: balance } = await supabase.rpc('get_seller_balance', { p_seller_id: seller_id });
    if (!balance || balance.available_balance < amount) {
      return Response.json({ success: false, error: `Insufficient balance. Available: ${balance?.available_balance || 0} MMK` }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('seller_payouts')
      .insert({ seller_id, amount, notes: notes || null })
      .select()
      .single();

    if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json({ success: false, error: err instanceof Error ? err.message : 'Invalid request' }, { status: 400 });
  }
}

// PATCH: admin approve/reject/complete
export async function PATCH(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id, action, rejection_reason } = body;

    if (!id || !action) {
      return Response.json({ success: false, error: 'id and action required' }, { status: 400 });
    }

    const updates: Record<string, unknown> = {};

    switch (action) {
      case 'approve':
        updates.status = 'approved';
        updates.approved_by = auth.userId;
        updates.approved_at = new Date().toISOString();
        break;
      case 'reject':
        updates.status = 'rejected';
        updates.rejection_reason = rejection_reason || null;
        break;
      case 'complete':
        updates.status = 'completed';
        updates.completed_at = new Date().toISOString();
        break;
      default:
        return Response.json({ success: false, error: 'Invalid action' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('seller_payouts')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) return Response.json({ success: false, error: error.message }, { status: 500 });

    // Send push notification to seller
    try {
      const { data: payout } = await supabase
        .from('seller_payouts')
        .select('seller_id, amount, canteen_sellers(profile_id)')
        .eq('id', id)
        .single();

      if (payout) {
        const profileId = (payout.canteen_sellers as unknown as Record<string, unknown>)?.profile_id;
        if (profileId) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('fcm_token')
            .eq('id', profileId)
            .not('fcm_token', 'is', null)
            .single();

          if (profile?.fcm_token) {
            const title = action === 'approve' ? 'Payout Approved' : action === 'complete' ? 'Payout Completed' : 'Payout Rejected';
            const msg = action === 'reject'
              ? `Your payout request was rejected. ${rejection_reason || ''}`
              : `Your payout of ${payout.amount.toLocaleString()} MMK has been ${action === 'approve' ? 'approved' : 'paid out'}.`;

            const fcmSA = process.env.FCM_SERVICE_ACCOUNT;
            if (fcmSA) {
              const sa = JSON.parse(fcmSA);
              const crypto = await import('crypto');
              function b64url(buf: Buffer | Uint8Array): string { return Buffer.from(buf).toString('base64url'); }
              const now = Math.floor(Date.now() / 1000);
              const h = b64url(Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
              const c = b64url(Buffer.from(JSON.stringify({ iss: sa.client_email, sub: sa.client_email, aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600, scope: 'https://www.googleapis.com/auth/firebase.messaging' })));
              const si = `${h}.${c}`;
              const sign = crypto.createSign('RSA-SHA256'); sign.update(si);
              const jwt = `${si}.${b64url(sign.sign(sa.private_key))}`;
              const tokenRes = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }) });
              const tokenData = await tokenRes.json();
              if (tokenData.access_token) {
                await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenData.access_token}` },
                  body: JSON.stringify({ message: { token: profile.fcm_token, notification: { title, body: msg }, data: { type: 'payout', payout_id: id, action }, android: { priority: 'high' }, apns: { payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } } } } }),
                });
              }
            }
          }
        }
      }
    } catch { /* push failure shouldn't fail the action */ }

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json({ success: false, error: err instanceof Error ? err.message : 'Invalid request' }, { status: 400 });
  }
}
