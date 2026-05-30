import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

interface AuthResult {
  userId: string;
  role: string;
}

/**
 * Verify the caller is an authenticated admin/staff user.
 * Extracts the access token from cookies or Authorization header.
 * Returns user info or null if unauthenticated.
 */
export async function verifyAdmin(request: Request): Promise<AuthResult | null> {
  try {
    // Try Authorization header first
    const authHeader = request.headers.get('authorization');
    let accessToken: string | null = null;

    if (authHeader?.startsWith('Bearer ')) {
      accessToken = authHeader.substring(7);
    }

    // Try cookie-based auth (Supabase stores tokens in cookies)
    if (!accessToken) {
      const cookieHeader = request.headers.get('cookie') || '';
      const cookies = Object.fromEntries(
        cookieHeader.split(';').map(c => {
          const [key, ...val] = c.trim().split('=');
          return [key, val.join('=')];
        })
      );

      // Supabase stores access token in sb-{ref}-auth-token cookie
      for (const [key, value] of Object.entries(cookies)) {
        if (key.includes('auth-token') && value) {
          try {
            const parsed = JSON.parse(decodeURIComponent(value));
            if (parsed.access_token) {
              accessToken = parsed.access_token;
              break;
            }
          } catch {
            // Not JSON, try raw value
            if (value.startsWith('ey')) {
              accessToken = value;
              break;
            }
          }
        }
      }
    }

    if (!accessToken) return null;

    // Verify the token with Supabase
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });

    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return null;

    // Check role from profiles table
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    const role = profile?.role || 'unknown';
    const allowedRoles = ['admin', 'counter_staff'];

    if (!allowedRoles.includes(role)) return null;

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
