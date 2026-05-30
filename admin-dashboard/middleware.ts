import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

// Rate limit tracking (in-memory, resets on cold start)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 60; // requests per window
const RATE_WINDOW = 60 * 1000; // 1 minute

// Known bot user agents to block
const BOT_PATTERNS = [
  /bot/i, /crawl/i, /spider/i, /scrape/i, /curl/i, /wget/i,
  /python-requests/i, /httpclient/i, /go-http/i, /java\//i,
  /libwww/i, /httpie/i, /postman/i, /insomnia/i,
];

// Allowed bots (search engines, uptime monitors)
const ALLOWED_BOTS = [
  /googlebot/i, /bingbot/i, /slurp/i, /duckduckbot/i,
  /vercel/i, /uptime/i,
];

function isBot(ua: string): boolean {
  if (ALLOWED_BOTS.some(p => p.test(ua))) return false;
  return BOT_PATTERNS.some(p => p.test(ua));
}

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW });
    return false;
  }

  entry.count++;
  return entry.count > RATE_LIMIT;
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const ua = request.headers.get('user-agent') || '';
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    request.headers.get('x-real-ip') || 'unknown';

  // 1. Block bots on dashboard and API routes
  if ((pathname.startsWith('/dashboard') || pathname.startsWith('/api/')) && isBot(ua)) {
    return new NextResponse('Forbidden', { status: 403 });
  }

  // 2. Rate limit API routes
  if (pathname.startsWith('/api/') && isRateLimited(ip)) {
    return NextResponse.json(
      { success: false, error: 'Too many requests. Please try again later.' },
      { status: 429 }
    );
  }

  // 3. Block direct access to API routes without referer (basic CSRF protection)
  if (pathname.startsWith('/api/') && request.method !== 'GET') {
    const referer = request.headers.get('referer') || '';
    const origin = request.headers.get('origin') || '';
    const host = request.headers.get('host') || '';

    // Allow if referer/origin matches the host, or if it's a server-side call
    const isValidOrigin = referer.includes(host) || origin.includes(host) ||
      referer === '' && origin === ''; // Server-side calls may not have referer

    if (!isValidOrigin) {
      return NextResponse.json(
        { success: false, error: 'Forbidden' },
        { status: 403 }
      );
    }
  }

  // 4. Add security headers to all responses
  const response = NextResponse.next();

  // Prevent clickjacking
  response.headers.set('X-Frame-Options', 'DENY');
  // Prevent MIME type sniffing
  response.headers.set('X-Content-Type-Options', 'nosniff');
  // XSS protection
  response.headers.set('X-XSS-Protection', '1; mode=block');
  // Referrer policy
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  // Content Security Policy
  response.headers.set('Content-Security-Policy',
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: https: blob:; " +
    "font-src 'self' data:; " +
    "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://fcm.googleapis.com https://oauth2.googleapis.com; " +
    "frame-ancestors 'none';"
  );
  // HSTS
  response.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  // Permissions policy
  response.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

  return response;
}

export const config = {
  matcher: [
    // Match all dashboard and API routes
    '/dashboard/:path*',
    '/api/:path*',
    // Also protect the login page
    '/',
  ],
};
