// Supabase Edge Function: on-transaction
// Triggered by database webhook on INSERT into transactions table
// Sends push notification to parent's device when a purchase is made
// Uses FCM v1 API with service account (no legacy API needed)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// FCM v1 API uses a service account JSON for auth
const fcmServiceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT');
// Fallback: legacy server key (deprecated but still works)
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

// ---------------------------------------------------------------------------
// FCM v1 auth helpers
// ---------------------------------------------------------------------------

function base64url(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function getAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  token_uri: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const enc = new TextEncoder();
  const headerB64 = base64url(enc.encode(JSON.stringify(header)));
  const payloadB64 = base64url(enc.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  // Import RSA private key
  const pemBody = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '');
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    enc.encode(signingInput)
  );

  const jwt = `${signingInput}.${base64url(new Uint8Array(signature))}`;

  // Exchange JWT for access token
  const tokenRes = await fetch(serviceAccount.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

// ---------------------------------------------------------------------------
// Send via FCM v1 API (one message per token)
// ---------------------------------------------------------------------------

async function sendViaV1(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<unknown> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      }),
    }
  );
  return res.json();
}

// ---------------------------------------------------------------------------
// Send via legacy API (fallback)
// ---------------------------------------------------------------------------

async function sendViaLegacy(
  serverKey: string,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<unknown> {
  const res = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `key=${serverKey}`,
    },
    body: JSON.stringify({
      registration_ids: tokens,
      notification: { title, body },
      data,
    }),
  });
  return res.json();
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const transaction = payload.record;

    // Only notify on purchases
    if (transaction.type !== 'purchase') {
      return new Response(JSON.stringify({ message: 'Skipped: not a purchase' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get wallet → student
    const { data: wallet } = await supabase
      .from('wallets')
      .select('student_id')
      .eq('id', transaction.wallet_id)
      .single();

    if (!wallet) {
      return new Response(JSON.stringify({ error: 'Wallet not found' }), { status: 404 });
    }

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

    const tokens = parents
      .map((p: { fcm_token: string }) => p.fcm_token)
      .filter(Boolean);

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No valid tokens' }), { status: 200 });
    }

    // Format notification
    const formattedAmount = transaction.amount.toLocaleString();
    const formattedBalance = transaction.balance_after.toLocaleString();
    const title = `Purchase: ${formattedAmount} MMK`;
    const body = `${student?.full_name || 'Student'} spent ${formattedAmount} MMK at ${sellerName}. Balance: ${formattedBalance} MMK`;
    const data = {
      type: 'purchase',
      transaction_id: transaction.id,
      student_id: wallet.student_id,
      amount: transaction.amount.toString(),
      balance_after: transaction.balance_after.toString(),
    };

    // Try FCM v1 API first, fall back to legacy
    let results: unknown[] = [];

    if (fcmServiceAccountJson) {
      try {
        const sa = JSON.parse(fcmServiceAccountJson);
        const accessToken = await getAccessToken(sa);

        results = await Promise.all(
          tokens.map((token: string) =>
            sendViaV1(sa.project_id, accessToken, token, title, body, data)
          )
        );
      } catch (e) {
        console.error('FCM v1 failed, trying legacy:', e);
        // Fall through to legacy
      }
    }

    if (results.length === 0 && fcmServerKey) {
      const legacyResult = await sendViaLegacy(fcmServerKey, tokens, title, body, data);
      results = [legacyResult];
    }

    if (results.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No FCM credentials configured' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    return new Response(JSON.stringify({ success: true, fcm: results }), {
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
