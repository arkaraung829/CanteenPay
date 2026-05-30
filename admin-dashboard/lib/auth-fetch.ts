import { supabase } from './supabase';

/**
 * Wrapper around fetch that automatically adds the Supabase auth token.
 * Use this for all /api/ calls to pass authentication.
 */
export async function authFetch(
  url: string,
  options?: RequestInit
): Promise<Response> {
  const session = (await supabase.auth.getSession()).data.session;
  const token = session?.access_token;

  const headers = new Headers(options?.headers);
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  if (!headers.has('Content-Type') && options?.body) {
    headers.set('Content-Type', 'application/json');
  }

  return fetch(url, { ...options, headers });
}
