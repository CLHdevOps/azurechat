import { getToken } from "next-auth/jwt";
import { NextRequest, NextResponse } from "next/server";
import { nanoid } from "nanoid";

const requireAuth: string[] = [
  "/chat",
  "/api",
  "/reporting",
  "/unauthorized",
  "/persona",
  "/prompt"
];
const requireAdmin: string[] = ["/reporting"];

export async function middleware(request: NextRequest) {
  const res = NextResponse.next();
  const pathname = request.nextUrl.pathname;

  // Add request ID for tracing
  const requestId = request.headers.get('x-request-id') || nanoid();
  res.headers.set('x-request-id', requestId);

  // Add Datadog tracing headers for client-side correlation
  if (process.env.DD_TRACE_ENABLED === 'true') {
    res.headers.set('x-datadog-trace-enabled', 'true');
    res.headers.set('x-datadog-service', process.env.DD_SERVICE || 'azurechat');
    res.headers.set('x-datadog-env', process.env.DD_ENV || 'development');
  }

  // Log request (this will be enhanced with full logger when available)
  const startTime = Date.now();
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'info',
    message: 'Incoming request',
    service: process.env.DD_SERVICE || 'azurechat',
    environment: process.env.DD_ENV || 'development',
    category: 'request',
    method: request.method,
    url: pathname,
    userAgent: request.headers.get('user-agent') || 'unknown',
    requestId,
    ip: request.headers.get('x-forwarded-for') || 'unknown'
  }));

  if (requireAuth.some((path) => pathname.startsWith(path))) {
    const token = await getToken({
      req: request,
    });

    //check not logged in
    if (!token) {
      const url = new URL(`/`, request.url);
      return NextResponse.redirect(url);
    }

    if (requireAdmin.some((path) => pathname.startsWith(path))) {
      //check if not authorized
      if (!token.isAdmin) {
        const url = new URL(`/unauthorized`, request.url);
        return NextResponse.rewrite(url);
      }
    }
  }

  return res;
}

// note that middleware is not applied to api/auth as this is required to logon (i.e. requires anon access)
export const config = {
  matcher: [
    "/unauthorized/:path*",
    "/reporting/:path*",
    "/api/chat:path*",
    "/api/images:path*",
    "/chat/:path*",
  ],
};
