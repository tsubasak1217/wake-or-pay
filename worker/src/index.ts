/**
 * Wake or Pay — Discord OAuth2 code exchange.
 *
 * This Worker exists for exactly one reason: Discord's authorization-code
 * token exchange requires the application's **client secret**, and a client
 * secret shipped inside an APK is not a secret. It is not a backend for the
 * app; it holds no user data, no database and no session. One request in, one
 * answer out, nothing kept.
 *
 * What it deliberately does **not** return: the access token, the refresh
 * token, and the webhook's own token in isolation. The app is given the
 * webhook's `url` — which it needs, and which it already stores for a
 * hand-registered webhook — and nothing that could act as the user.
 */

/** The one endpoint. */
const EXCHANGE_PATH = '/discord/exchange';

const DISCORD_TOKEN_URL = 'https://discord.com/api/oauth2/token';
const DISCORD_GUILDS_URL = 'https://discord.com/api/users/@me/guilds';

/** How long Discord is given to answer, per call. */
const DISCORD_TIMEOUT_MS = 10_000;

/** Rate limit: this many exchanges per IP per window. */
const RATE_LIMIT = 10;
const RATE_WINDOW_MS = 60_000;

export interface Env {
  /**
   * Set with `wrangler secret put DISCORD_CLIENT_SECRET`. **Never** in
   * wrangler.toml, never in the repo — a secret in a config file is a secret
   * in every clone and every CI log.
   */
  DISCORD_CLIENT_SECRET: string;

  /** The Discord application's client ID. Public; lives in wrangler.toml. */
  DISCORD_CLIENT_ID: string;

  /**
   * Optional, comma separated. Browser origins allowed to call this. Empty
   * (the default) means **no browser origin is allowed at all**, which is the
   * right answer for a Worker only a native app talks to.
   */
  ALLOWED_ORIGINS?: string;
}

interface ExchangeRequest {
  code?: unknown;
  redirect_uri?: unknown;
  code_verifier?: unknown;
}

/** What the app gets back. Nothing else is ever in this object. */
interface ExchangeResponse {
  webhook: {
    id: string;
    url: string;
    channel_id: string | null;
    guild_id: string | null;
    name: string | null;
  };
  guild_name: string | null;
  channel_name: string | null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      // Nothing here is cacheable and a cached token exchange would be a bug
      // with somebody else's webhook in it.
      'cache-control': 'no-store',
    },
  });
}

function error(message: string, status: number): Response {
  return json({ error: message }, status);
}

/**
 * Best-effort per-IP rate limiting.
 *
 * In module scope, so it lives as long as the isolate does — which is not
 * long, and is per-colo. That makes this a **speed bump, not a wall**: it
 * stops a loop hammering one Worker instance, and it is honest about not
 * being a distributed limiter. A real one would need Durable Objects, which
 * is a lot of machinery for an endpoint whose only cost is Discord's own rate
 * limit on the application.
 */
const hits = new Map<string, number[]>();

function rateLimited(ip: string, now: number): boolean {
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

/**
 * A browser Origin, if there is one, must be on the allowlist.
 *
 * A native app sends no Origin at all, which is the expected case and is
 * allowed. A page on the open web sends one, and refusing an unlisted origin
 * stops this endpoint being used as somebody else's exchange oracle — the
 * secret is the whole value of the Worker, and every request spends it.
 */
function originAllowed(request: Request, env: Env): boolean {
  const origin = request.headers.get('Origin');
  if (!origin) return true;
  const allowed = (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return allowed.includes(origin);
}

async function discordFetch(
  url: string,
  init: RequestInit,
): Promise<Response | null> {
  try {
    return await fetch(url, {
      ...init,
      signal: AbortSignal.timeout(DISCORD_TIMEOUT_MS),
    });
  } catch {
    return null;
  }
}

/**
 * The guild's human name.
 *
 * `/users/@me/guilds` is what `identify` plus the authorization already
 * allows, and it is the only way to turn the webhook's `guild_id` into
 * 「みんなのサーバー」. Every failure is null: the app falls back to the
 * webhook's own name, which is worse but never wrong.
 */
async function fetchGuildName(
  accessToken: string,
  guildId: string | null,
): Promise<string | null> {
  if (!guildId) return null;
  const response = await discordFetch(DISCORD_GUILDS_URL, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!response || !response.ok) return null;
  try {
    const guilds = (await response.json()) as Array<{
      id?: string;
      name?: string;
    }>;
    if (!Array.isArray(guilds)) return null;
    const match = guilds.find((g) => g?.id === guildId);
    return typeof match?.name === 'string' && match.name ? match.name : null;
  } catch {
    return null;
  }
}

function asString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname !== EXCHANGE_PATH) return error('not found', 404);
    if (request.method !== 'POST') return error('method not allowed', 405);
    if (!originAllowed(request, env)) return error('origin not allowed', 403);

    const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
    if (rateLimited(ip, Date.now())) {
      return error('too many requests', 429);
    }

    if (!env.DISCORD_CLIENT_SECRET) {
      // Deploying without the secret is the most likely setup mistake, and
      // 「500」 alone would send the user looking in the app.
      return error('DISCORD_CLIENT_SECRET is not set on this Worker', 500);
    }

    let body: ExchangeRequest;
    try {
      body = (await request.json()) as ExchangeRequest;
    } catch {
      return error('body must be JSON', 400);
    }

    const code = asString(body.code);
    const redirectUri = asString(body.redirect_uri);
    const codeVerifier = asString(body.code_verifier);
    if (!code || !redirectUri) {
      return error('code and redirect_uri are required', 400);
    }

    const form = new URLSearchParams({
      client_id: env.DISCORD_CLIENT_ID,
      client_secret: env.DISCORD_CLIENT_SECRET,
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
    });
    // PKCE is passed through if the app ever starts sending it. Discord does
    // not require it for this flow today, and nothing is gained by refusing a
    // verifier that arrives.
    if (codeVerifier) form.set('code_verifier', codeVerifier);

    const tokenResponse = await discordFetch(DISCORD_TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: form.toString(),
    });
    if (!tokenResponse) return error('could not reach Discord', 502);
    if (!tokenResponse.ok) {
      // The status is passed on, without Discord's body: the body of a failed
      // token exchange echoes parameters back, and the app has nothing to do
      // with them beyond 「連携できませんでした」.
      return error(`Discord refused the exchange`, tokenResponse.status);
    }

    let token: Record<string, unknown>;
    try {
      token = (await tokenResponse.json()) as Record<string, unknown>;
    } catch {
      return error('Discord answered with something that is not JSON', 502);
    }

    const webhook = token.webhook as Record<string, unknown> | undefined;
    if (!webhook || !asString(webhook.url) || !asString(webhook.id)) {
      // No webhook means the authorization did not include webhook.incoming,
      // or the user picked nothing. Either way there is nothing to register.
      return error('no webhook came back from Discord', 502);
    }

    const guildId = asString(webhook.guild_id);
    const accessToken = asString(token.access_token);
    const guildName = accessToken
      ? await fetchGuildName(accessToken, guildId)
      : null;

    const answer: ExchangeResponse = {
      webhook: {
        id: asString(webhook.id)!,
        url: asString(webhook.url)!,
        channel_id: asString(webhook.channel_id),
        guild_id: guildId,
        name: asString(webhook.name),
      },
      guild_name: guildName,
      // The channel's name needs a bot in the guild or `guilds.members.read`
      // — neither of which this app has, and asking for either would put a
      // scarier consent screen in front of the user for a nicer label. Null,
      // and the app falls back to the webhook's own name.
      channel_name: null,
    };
    return json(answer);
  },
};
