/**
 * Device tokens.
 *
 * The token is 32 bytes from the platform CSPRNG, base64url-encoded — 43
 * characters, no padding, URL- and header-safe. It is returned **once**, to the
 * app that asked for it, and after that it exists only in the app's secure
 * store. What this Worker keeps is `sha256(token)` in hex, so a dump of the D1
 * does not hand anybody a working `Authorization` header.
 *
 * There is no expiry and no refresh in Phase 1: the recovery path for a lost
 * token is re-registering the same `installId`, which mints a new token and
 * replaces the stored hash (see docs/BILLING_API.md).
 */

import type { BillingStore, DeviceRow } from './store';

/** 32 random bytes as base64url. 43 characters. */
export function newDeviceToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64url(bytes);
}

export function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return hex(new Uint8Array(digest));
}

export function hex(bytes: Uint8Array): string {
  let out = '';
  for (const byte of bytes) out += byte.toString(16).padStart(2, '0');
  return out;
}

/**
 * The device behind `Authorization: Bearer …`, or null.
 *
 * Null covers every failure the same way — no header, wrong scheme, unknown
 * token — because the caller answers all of them with one `401 unauthorized`.
 * The token is never logged, and never echoed back in an error.
 */
export async function authenticate(
  request: Request,
  store: BillingStore,
): Promise<DeviceRow | null> {
  const header = request.headers.get('Authorization');
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  if (!match) return null;
  const token = match[1].trim();
  if (!token) return null;
  return store.deviceByTokenHash(await sha256Hex(token));
}

/** Constant-time comparison of two equal-length hex strings. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
