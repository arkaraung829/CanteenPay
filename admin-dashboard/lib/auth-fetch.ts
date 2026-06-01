import { supabase } from './supabase';

// Cache token to avoid repeated getSession() calls
let _cachedToken: string | null = null;
let _tokenExpiry = 0;

async function getToken(): Promise<string | null> {
  const now = Date.now();
  // Reuse cached token if still valid (refresh 5 min before expiry)
  if (_cachedToken && _tokenExpiry > now + 300000) {
    return _cachedToken;
  }
  const session = (await supabase.auth.getSession()).data.session;
  _cachedToken = session?.access_token || null;
  _tokenExpiry = session?.expires_at ? session.expires_at * 1000 : 0;
  return _cachedToken;
}

// Clear cache on auth state change
supabase.auth.onAuthStateChange(() => {
  _cachedToken = null;
  _tokenExpiry = 0;
});

/**
 * Wrapper around fetch that automatically adds the Supabase auth token.
 * Use this for all /api/ calls to pass authentication.
 */
export async function authFetch(
  url: string,
  options?: RequestInit
): Promise<Response> {
  const token = await getToken();

  const headers = new Headers(options?.headers);
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  if (!headers.has('Content-Type') && options?.body) {
    headers.set('Content-Type', 'application/json');
  }

  return fetch(url, { ...options, headers });
}
