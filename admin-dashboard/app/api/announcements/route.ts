import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const schoolId = searchParams.get('school_id') || '';

  let query = supabase
    .from('announcements')
    .select('*, profiles!announcements_author_id_fkey(full_name)')
    .order('created_at', { ascending: false });

  if (schoolId) {
    query = query.eq('school_id', schoolId);
  }

  const { data, error } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  return Response.json({ success: true, data: data || [] });
}

export async function POST(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { title, title_my, body: bodyText, body_my, target_audience, school_id, author_id, send_push } = body;

    if (!title || !bodyText) {
      return Response.json({ success: false, error: 'Title and body are required' }, { status: 400 });
    }

    // Get school_id if not provided
    let schoolId = school_id;
    if (!schoolId) {
      const { data: schools } = await supabase
        .from('schools')
        .select('id')
        .eq('is_active', true)
        .limit(1);
      schoolId = schools?.[0]?.id;
    }

    if (!schoolId) {
      return Response.json({ success: false, error: 'No school found' }, { status: 400 });
    }

    // Get author_id — use provided or find first admin
    let authorId = author_id;
    if (!authorId) {
      const { data: admins } = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'admin')
        .eq('school_id', schoolId)
        .limit(1);
      authorId = admins?.[0]?.id;
      // Fallback: any admin
      if (!authorId) {
        const { data: anyAdmin } = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .limit(1);
        authorId = anyAdmin?.[0]?.id;
      }
    }

    // Insert announcement
    const { data, error } = await supabase
      .from('announcements')
      .insert({
        school_id: schoolId,
        author_id: authorId,
        title,
        title_my: title_my || null,
        body: bodyText,
        body_my: body_my || null,
        target_audience: target_audience || ['all'],
        is_published: true,
        published_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    // Send push notification if requested
    let pushResult = null;
    if (send_push) {
      pushResult = await sendPushToAudience(supabase, schoolId, target_audience || ['all'], title, bodyText);
    }

    return Response.json({ success: true, data, push: pushResult });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}

export async function DELETE(request: NextRequest) {
  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { id } = body;

    if (!id) {
      return Response.json({ success: false, error: 'ID is required' }, { status: 400 });
    }

    const { error } = await supabase
      .from('announcements')
      .delete()
      .eq('id', id);

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    return Response.json({ success: true });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}

// Send push notification to target audience
async function sendPushToAudience(
  supabase: ReturnType<typeof createAdminClient>,
  schoolId: string,
  targetAudience: string[],
  title: string,
  body: string,
) {
  try {
    // Build role filter based on target audience
    const roles: string[] = [];
    if (targetAudience.includes('all')) {
      roles.push('parent', 'student', 'seller');
    } else {
      if (targetAudience.includes('parent')) roles.push('parent');
      if (targetAudience.includes('student')) roles.push('student');
      if (targetAudience.includes('seller')) roles.push('seller');
    }

    // Get FCM tokens for users in the target audience
    const { data: profiles } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('school_id', schoolId)
      .in('role', roles)
      .not('fcm_token', 'is', null);

    if (!profiles || profiles.length === 0) {
      return { sent: 0, message: 'No FCM tokens found' };
    }

    const tokens = profiles
      .map((p: { fcm_token: string }) => p.fcm_token)
      .filter(Boolean);

    if (tokens.length === 0) {
      return { sent: 0, message: 'No valid tokens' };
    }

    // Get service account from env
    const fcmServiceAccountJson = process.env.FCM_SERVICE_ACCOUNT;
    if (!fcmServiceAccountJson) {
      return { sent: 0, error: 'FCM_SERVICE_ACCOUNT not configured' };
    }

    // Use FCM v1 API directly
    let sa;
    try {
      sa = JSON.parse(fcmServiceAccountJson);
    } catch {
      return { sent: 0, error: 'FCM_SERVICE_ACCOUNT is not valid JSON' };
    }
    const accessToken = await getGoogleAccessToken(sa);

    const results = await Promise.all(
      tokens.map(async (token: string) => {
        try {
          const res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
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
                  data: { type: 'announcement' },
                  android: { priority: 'high' },
                  apns: { payload: { aps: { sound: 'default', badge: 1 } } },
                },
              }),
            }
          );
          return res.json();
        } catch {
          return { error: 'Failed to send' };
        }
      })
    );

    const successCount = results.filter(
      (r: Record<string, unknown>) => r.name && !r.error
    ).length;

    return { sent: successCount, total: tokens.length };
  } catch (e) {
    return { sent: 0, error: (e as Error).message };
  }
}

// Get Google OAuth2 access token from service account
async function getGoogleAccessToken(sa: { client_email: string; private_key: string; token_uri?: string }) {
  // Use Node.js crypto for JWT signing
  const crypto = await import('crypto');

  function b64url(buf: Buffer | Uint8Array): string {
    return Buffer.from(buf).toString('base64url');
  }

  const now = Math.floor(Date.now() / 1000);
  const header = b64url(Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = b64url(Buffer.from(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })));

  const signingInput = `${header}.${claims}`;
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(signingInput);
  const sig = sign.sign(sa.private_key);
  const jwt = `${signingInput}.${b64url(sig)}`;

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
    throw new Error(`OAuth2: ${data.error} - ${data.error_description}`);
  }
  return data.access_token as string;
}
