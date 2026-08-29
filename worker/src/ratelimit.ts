/**
 * Best-effort per-IP rate limiting, shared by the Discord exchange and the
 * billing endpoints.
 *
 * In module scope, so it lives as long as the isolate does — which is not
 * long, and is per-colo. That makes this a **speed bump, not a wall**: it
 * stops a loop hammering one Worker instance, and it is honest about not
 * being a distributed limiter. A real one would need Durable Objects, which
 * is a lot of machinery for endpoints whose only cost is somebody else's rate
 * limit on the application.
 *
 * It lives in its own module only so that `index.ts` and `billing.ts` can both
 * reach the *same* map without importing each other in a circle.
 */

/** Rate limit: this many requests per IP per window. */
export const RATE_LIMIT = 10;
export const RATE_WINDOW_MS = 60_000;

const hits = new Map<string, number[]>();

export function rateLimited(ip: string, now: number): boolean {
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < RATE_WINDOW_MS);
  recent.push(now);
  hits.set(ip, recent);
  // Unbounded growth is the other way this leaks; the map is swept whenever
  // it gets big rather than on a timer, because a Worker has no timer.
  if (hits.size > 1000) {
    for (const [key, times] of hits) {
      if (times.every((t) => now - t >= RATE_WINDOW_MS)) hits.delete(key);
    }
  }
  return recent.length > RATE_LIMIT;
}
