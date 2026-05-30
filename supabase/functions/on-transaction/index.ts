// Supabase Edge Function: on-transaction
// Triggered by database webhook on INSERT into transactions table
// Sends push notification to parent's device via FCM v1 API

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const fcmServiceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT');

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
// JWT helper — self-contained, works in Deno Deploy
// ---------------------------------------------------------------------------

function base64UrlEncode(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.length; i++) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlEncodeStr(str: string): string {
  return base64UrlEncode(new TextEncoder().encode(str));
}

async function createSignedJwt(
  clientEmail: string,
  privateKeyPem: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = base64UrlEncodeStr(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64UrlEncodeStr(JSON.stringify({
    iss: clientEmail,
    sub: clientEmail,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }));

  const signingInput = `${header}.${claims}`;

  // Parse PEM to DER
  const pemLines = privateKeyPem.split('\n');
  const b64 = pemLines.filter(line =>
    !line.startsWith('-----') && line.trim().length > 0
  ).join('');
  const der = Uint8Array.from(atob(b64), c => c.charCodeAt(0));

  // Import key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: { name: 'SHA-256' } },
    false,
    ['sign'],
  );

  // Sign
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(sig))}`;
}

async function getAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const jwt = await createSignedJwt(sa.client_email, sa.private_key);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (data.error) {
    throw new Error(`OAuth2 error: ${data.error} - ${data.error_description}`);
  }
  return data.access_token;
}

// ---------------------------------------------------------------------------
// FCM v1 send
// ---------------------------------------------------------------------------

async function sendNotification(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
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
    },
  );
  return res.json();
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const transaction = payload.record;

    if (transaction.type !== 'purchase' && transaction.type !== 'deposit' && transaction.type !== 'refund') {
      return new Response(JSON.stringify({ message: 'Skipped: not a purchase/deposit/refund' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!fcmServiceAccountJson) {
      return new Response(
        JSON.stringify({ success: false, message: 'FCM_SERVICE_ACCOUNT not configured' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
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

    // Format notification based on type
    const formattedAmount = transaction.amount.toLocaleString();
    const formattedBalance = transaction.balance_after.toLocaleString();
    const studentName = student?.full_name || 'Student';

    let title: string;
    let body: string;

    if (transaction.type === 'purchase') {
      title = `Purchase: ${formattedAmount} MMK`;
      body = `${studentName} spent ${formattedAmount} MMK at ${sellerName}. Balance: ${formattedBalance} MMK`;
    } else if (transaction.type === 'deposit') {
      title = `Deposit: +${formattedAmount} MMK`;
      body = `${studentName} received ${formattedAmount} MMK deposit. Balance: ${formattedBalance} MMK`;
    } else {
      title = `Refund: +${formattedAmount} MMK`;
      body = `${studentName} received a ${formattedAmount} MMK refund. Balance: ${formattedBalance} MMK`;
    }

    const notifData = {
      type: transaction.type,
      transaction_id: transaction.id,
      student_id: wallet.student_id,
      amount: transaction.amount.toString(),
      balance_after: transaction.balance_after.toString(),
    };

    // Authenticate and send purchase notification
    const sa = JSON.parse(fcmServiceAccountJson);
    const accessToken = await getAccessToken(sa);

    const results = await Promise.all(
      tokens.map((token: string) =>
        sendNotification(sa.project_id, accessToken, token, title, body, notifData)
      ),
    );

    // Low balance alert — notify if balance dropped below 2000 MMK
    const LOW_BALANCE_THRESHOLD = 2000;
    if (transaction.balance_after < LOW_BALANCE_THRESHOLD) {
      const lowTitle = `Low Balance Alert`;
      const lowBody = `${student?.full_name || 'Student'}'s balance is ${formattedBalance} MMK. Please top up soon.`;
      const lowData = {
        type: 'low_balance',
        student_id: wallet.student_id,
        balance: transaction.balance_after.toString(),
      };

      await Promise.all(
        tokens.map((token: string) =>
          sendNotification(sa.project_id, accessToken, token, lowTitle, lowBody, lowData)
        ),
      );
    }

    return new Response(JSON.stringify({ success: true, fcm: results }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message, stack: (error as Error).stack }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
