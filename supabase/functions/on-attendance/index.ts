// Supabase Edge Function: on-attendance
// Triggered by database webhook on INSERT/UPDATE into attendance table
// Sends push notification to parent when child is marked absent

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const fcmServiceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT');

interface AttendanceRecord {
  id: string;
  student_id: string;
  school_id: string;
  date: string;
  status: string;
  marked_by: string;
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE';
  table: string;
  record: AttendanceRecord;
  schema: string;
}

// JWT helpers (same as on-transaction)
function base64UrlEncode(data: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < data.length; i++) binary += String.fromCharCode(data[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlEncodeStr(str: string): string {
  return base64UrlEncode(new TextEncoder().encode(str));
}

async function createSignedJwt(clientEmail: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncodeStr(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64UrlEncodeStr(JSON.stringify({
    iss: clientEmail, sub: clientEmail,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }));
  const signingInput = `${header}.${claims}`;
  const pemLines = privateKeyPem.split('\n');
  const b64 = pemLines.filter(line => !line.startsWith('-----') && line.trim().length > 0).join('');
  const der = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der.buffer, { name: 'RSASSA-PKCS1-v1_5', hash: { name: 'SHA-256' } }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${base64UrlEncode(new Uint8Array(sig))}`;
}

async function getAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const jwt = await createSignedJwt(sa.client_email, sa.private_key);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  });
  const data = await res.json();
  if (data.error) throw new Error(`OAuth2: ${data.error}`);
  return data.access_token;
}

async function sendNotification(projectId: string, accessToken: string, token: string, title: string, body: string, data: Record<string, string>): Promise<unknown> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ message: { token, notification: { title, body }, data, android: { priority: 'high' }, apns: { payload: { aps: { sound: 'default', badge: 1, 'content-available': 1, 'mutable-content': 1 } } } } }),
  });
  return res.json();
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const record = payload.record;

    // Only notify on present (scanned attendance)
    if (record.status !== 'present') {
      return new Response(JSON.stringify({ message: 'Skipped: not present' }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    if (!fcmServiceAccountJson) {
      return new Response(JSON.stringify({ message: 'FCM not configured' }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get student name
    const { data: student } = await supabase.from('students').select('full_name').eq('id', record.student_id).single();

    // Get linked parents' FCM tokens
    const { data: links } = await supabase.from('parent_student_links').select('parent_id').eq('student_id', record.student_id);
    if (!links || links.length === 0) {
      return new Response(JSON.stringify({ message: 'No linked parents' }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    const parentIds = links.map((l: { parent_id: string }) => l.parent_id);
    const { data: parents } = await supabase.from('profiles').select('fcm_token').in('id', parentIds).not('fcm_token', 'is', null);
    if (!parents || parents.length === 0) {
      return new Response(JSON.stringify({ message: 'No FCM tokens' }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    const tokens = parents.map((p: { fcm_token: string }) => p.fcm_token).filter(Boolean);
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No valid tokens' }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    const studentName = student?.full_name || 'Your child';
    // Convert to Myanmar time (UTC+6:30)
    const now = new Date();
    const myanmarOffset = 6.5 * 60 * 60 * 1000;
    const myanmarTime = new Date(now.getTime() + myanmarOffset);
    const hours = myanmarTime.getUTCHours();
    const minutes = myanmarTime.getUTCMinutes();
    const ampm = hours >= 12 ? 'PM' : 'AM';
    const h12 = hours > 12 ? hours - 12 : (hours === 0 ? 12 : hours);
    const timeStr = `${h12}:${minutes.toString().padStart(2, '0')} ${ampm}`;
    const dateStr = `${myanmarTime.getUTCDate()}/${myanmarTime.getUTCMonth() + 1}/${myanmarTime.getUTCFullYear()}`;
    const title = 'Attendance: Present';
    const body = `${studentName} arrived at school on ${dateStr} at ${timeStr}`;
    const data = { type: 'attendance', student_id: record.student_id, status: 'present', date: record.date };

    const sa = JSON.parse(fcmServiceAccountJson);
    const accessToken = await getAccessToken(sa);

    const results = await Promise.all(tokens.map((token: string) => sendNotification(sa.project_id, accessToken, token, title, body, data)));

    return new Response(JSON.stringify({ success: true, fcm: results }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
