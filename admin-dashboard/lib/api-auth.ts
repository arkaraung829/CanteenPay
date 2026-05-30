import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

interface AuthResult {
  userId: string;
  role: string;
}

/**
 * Verify the caller is an authenticated admin/staff user.
 * Checks Authorization header, cookies, and Supabase auth tokens.
 * Returns user info or null if unauthenticated.
 */
export async function verifyAdmin(request: Request): Promise<AuthResult | null> {
  try {
    let accessToken: string | null = null;

    // 1. Try Authorization header
    const authHeader = request.headers.get('authorization');
    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.substring(7);
    }

    // 2. Try cookies (Supabase stores session in sb-{ref}-auth-token)
    if (!accessToken) {
      const cookieHeader = request.headers.get('cookie') || '';
      // Parse all cookies
      const cookies: Record<string, string> = {};
      cookieHeader.split(';').forEach(c => {
        const [key, ...val] = c.trim().split('=');
        if (key) cookies[key.trim()] = val.join('=');
      });

      // Look for Supabase auth token cookie
      for (const [key, value] of Object.entries(cookies)) {
        if (key.includes('auth-token') && value) {
          try {
            const decoded = decodeURIComponent(value);
            // Could be base64 encoded JSON
            const parsed = JSON.parse(decoded);
            if (parsed?.access_token) {
              accessToken = parsed.access_token;
              break;
            }
          } catch {
            // Try if it looks like a JWT
            const decoded = decodeURIComponent(value);
            if (decoded.startsWith('ey')) {
              accessToken = decoded;
              break;
            }
          }
        }
      }
    }

    if (!accessToken) return null;

    // 3. Verify token with Supabase
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });

    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return null;

    // 4. Check role
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    const role = profile?.role || 'unknown';
    if (!['admin', 'counter_staff'].includes(role)) return null;

    return { userId: user.id, role };
  } catch {
    return null;
  }
}

/**
 * Verify the caller is an authenticated admin/staff OR teacher user.
 * Teachers have limited access (e.g., attendance only).
 */
export async function verifyAdminOrTeacher(request: Request): Promise<AuthResult | null> {
  try {
    let accessToken: string | null = null;

    const authHeader = request.headers.get('authorization');
    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.substring(7);
    }

    if (!accessToken) {
      const cookieHeader = request.headers.get('cookie') || '';
      const cookies: Record<string, string> = {};
      cookieHeader.split(';').forEach(c => {
        const [key, ...val] = c.trim().split('=');
        if (key) cookies[key.trim()] = val.join('=');
      });

      for (const [key, value] of Object.entries(cookies)) {
        if (key.includes('auth-token') && value) {
          try {
            const decoded = decodeURIComponent(value);
            const parsed = JSON.parse(decoded);
            if (parsed?.access_token) {
              accessToken = parsed.access_token;
              break;
            }
          } catch {
            const decoded = decodeURIComponent(value);
            if (decoded.startsWith('ey')) {
              accessToken = decoded;
              break;
            }
          }
        }
      }
    }

    if (!accessToken) return null;

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });

    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return null;

    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    const role = profile?.role || 'unknown';
    if (!['admin', 'counter_staff', 'teacher'].includes(role)) return null;

    return { userId: user.id, role };
  } catch {
    return null;
  }
}

/**
 * Returns a 401 JSON response.
 */
export function unauthorizedResponse() {
  return Response.json(
    { success: false, error: 'Unauthorized' },
    { status: 401 }
  );
}

/**
 * Sanitize error message — never expose raw DB errors to clients.
 */
export function safeErrorResponse(err: unknown, status = 500) {
  if (process.env.NODE_ENV === 'development') {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Unknown error' },
      { status }
    );
  }
  return Response.json(
    { success: false, error: 'An error occurred. Please try again.' },
    { status }
  );
}
