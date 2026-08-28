/**
 * Wake or Pay — Discord OAuth2 landing pad and code exchange.
 *
 * Three jobs, and deliberately no fourth:
 *
 * 1. `POST /discord/exchange` — Discord's authorization-code token exchange
 *    requires the application's **client secret**, and a client secret shipped
 *    inside an APK is not a secret. One request in, one answer out, nothing
 *    kept: no database, no session, no user data.
 * 2. `GET /discord/callback` — the **redirect URI**. Discord refuses a custom
 *    scheme (`wakeorpay://…`) for this application outright
 *    (「Redirect URI is not supported by client」), so the redirect has to be
 *    https. This page's whole life is to bounce straight back into the app.
 * 3. `GET /.well-known/assetlinks.json` — the Digital Asset Links statement
 *    that makes Android hand `https://…/discord/callback` to the app itself
 *    (App Links) instead of opening a browser tab on it.
 *
 * What it deliberately does **not** return to the app: the access token, the
 * refresh token, and the webhook's token in isolation. The app gets the
 * webhook's `url` — which it needs and already stores for a hand-registered
 * webhook — plus, for 「Discord で連携」, the four public fields of the user.
 */

const EXCHANGE_PATH = '/discord/exchange';
const CALLBACK_PATH = '/discord/callback';
/**
 * A second **App Link** path, carrying the same parameters onward.
 *
 * Its whole reason to exist is a Chromium behaviour: a verified App Link is
 * only handed to the app when the navigation *starts* somewhere the browser
 * treats as a fresh top-level navigation. A redirect chain that ends on
 * `/discord/callback` — which is exactly what Discord does — stays in the
 * browser. A **new** navigation to a different verified path, started by the
 * landing page's script, is a second chance at the same door.
 *
 * When it opens the app, this handler never runs. When it does run, the app
 * was not there to take it, and the page it returns is the manual one: no
 * auto-attempt, because an auto-attempt here is how a loop starts.
 */
const RETURN_PATH = '/discord/callback/return';
const ASSETLINKS_PATH = '/.well-known/assetlinks.json';

const DISCORD_TOKEN_URL = 'https://discord.com/api/oauth2/token';
const DISCORD_GUILDS_URL = 'https://discord.com/api/users/@me/guilds';
const DISCORD_ME_URL = 'https://discord.com/api/users/@me';

/** How long Discord is given to answer, per call. */
const DISCORD_TIMEOUT_MS = 10_000;

/** Rate limit: this many exchanges per IP per window. */
const RATE_LIMIT = 10;
const RATE_WINDOW_MS = 60_000;

/**
 * The Android application the callback page bounces back into, and the one
 * `assetlinks.json` vouches for.
 */
const ANDROID_PACKAGE = 'com.wakeorpay.wake_or_pay';

/** The custom scheme `MainActivity` claims, for the fallback bounce. */
const APP_SCHEME = 'wakeorpay';

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

  /**
   * The SHA-256 fingerprint of the certificate the installed APK is signed
   * with, colon separated and upper case — exactly `keytool -list -v`'s form.
   * Public by nature: it is the fingerprint of a *public* certificate, and its
   * whole purpose is to be published here.
   *
   * Get it with:
   *   keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore \
   *           -alias androiddebugkey -storepass android
   * for a build signed with the debug key (which is what
   * `android/app/build.gradle.kts` still does), or from the release keystore
   * once there is one. **Change the keystore and this must change with it**, or
   * Android stops verifying the app link and the callback opens a browser.
   */
  ANDROID_CERT_SHA256?: string;
}

interface ExchangeRequest {
  code?: unknown;
  redirect_uri?: unknown;
  code_verifier?: unknown;
  /** `'identify'` or `'webhook'`. Absent means `'webhook'`. */
  mode?: unknown;
}

/** What 「チャンネルを連携」 gets back. Nothing else is ever in this object. */
interface WebhookExchangeResponse {
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

/** What 「Discord で連携」 gets back: the four public fields of `/users/@me`. */
interface IdentityExchangeResponse {
  user: {
    id: string;
    username: string | null;
    global_name: string | null;
    avatar: string | null;
  };
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

/** HTML-escapes text destined for a text node or a quoted attribute. */
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * The landing page Discord redirects the browser to.
 *
 * It exists because Discord will not redirect to `wakeorpay://…` — the custom
 * scheme is refused at the authorize step with 「Redirect URI is not supported
 * by client」 before the user ever sees a consent screen. So the redirect is
 * https, lands here, and this page hands the parameters onwards to the app.
 *
 * **The tap is the reliable path, and it is therefore the primary one.**
 * That is not a preference, it is what Chromium does. Measured on the user's
 * Pixel with Brave as the default browser, everything on the Android side was
 * already right — `pm get-app-links` said `verified`, and
 * `pm query-activities` on the callback URL resolved to `MainActivity` — and
 * the app still did not open after 認証. Two Chromium rules explain it and
 * nothing else does:
 *
 * - A verified App Link reached at the **end of a redirect chain** (which is
 *   precisely how Discord delivers this page) is not handed to the app.
 *   Chromium only offers the app a navigation it considers user-initiated.
 * - A scripted navigation to an **unknown scheme** (`wakeorpay://`) without a
 *   user gesture is blocked outright. `location.replace` from a load handler
 *   is exactly that shape, so the old page's one automatic attempt was being
 *   dropped on the floor silently.
 *
 * So the order here is, in descending reliability:
 *
 * 1. **A big anchor whose `href` is an `intent://` URL.** A tap is a user
 *    gesture, and `intent://` naming the package is the form Chromium honours
 *    most consistently. This is the one that works, and it is the one the page
 *    is built around.
 * 2. **Two automatic attempts**, best effort, once each: `intent://` first
 *    (from a `setTimeout`, so it is a navigation and not a load-handler
 *    side-effect), then a **fresh top-level navigation** to the other verified
 *    App Link path, {@link RETURN_PATH}. Some Chromium builds hand *that* one
 *    to the app because it is a new navigation rather than a redirect target.
 * 3. **App Links proper.** When Android verified `assetlinks.json` *and* the
 *    navigation qualifies, the browser never opens this page at all. Lovely
 *    when it happens; this page is what happens when it does not.
 *
 * **The code is never logged and never rendered in text** — it is a one-shot
 * credential. It only ever appears inside the URLs, and this page is
 * `no-store` so no cache keeps it.
 *
 * @param autoAttempt false on {@link RETURN_PATH}. That page is reached only
 * *because* an automatic attempt did not open the app, so repeating it there
 * is how the browser ends up in a navigation loop.
 */
function callbackPage(
  params: URLSearchParams,
  selfOrigin: string,
  autoAttempt: boolean,
): string {
  // Only the parameters the app's parser reads are carried across. Anything
  // else Discord or a proxy appends is dropped rather than reflected. What
  // survives is percent-encoded by URLSearchParams, so the query is already
  // free of quotes and angle brackets before anything below escapes it again.
  const carried = new URLSearchParams();
  for (const key of ['code', 'state', 'error', 'error_description']) {
    const value = params.get(key);
    if (value) carried.set(key, value);
  }
  const query = carried.toString();
  const suffix = query ? `?${query}` : '';

  const appUrl = `${APP_SCHEME}://discord/callback${suffix}`;
  const returnUrl = `${selfOrigin}${RETURN_PATH}${suffix}`;
  // Where Chromium goes when the package is **not installed**. It must not be
  // this page: this page auto-attempts, the attempt fails again, and that is a
  // loop with a spent authorization code in the address bar. RETURN_PATH never
  // auto-attempts, so it is a dead end on purpose.
  const fallbackUrl = returnUrl;
  const intentUrl =
    `intent://discord/callback${suffix}` +
    `#Intent;scheme=${APP_SCHEME};package=${ANDROID_PACKAGE};` +
    `S.browser_fallback_url=${encodeURIComponent(fallbackUrl)};end`;

  const appHref = escapeHtml(appUrl);
  const intentHref = escapeHtml(intentUrl);
  const returnHref = escapeHtml(returnUrl);
  // A JSON string literal is a JS string literal here, and `<` is escaped so
  // no value can close this script element early.
  const js = (value: string) =>
    JSON.stringify(value).replace(/</g, '\\u003c');

  const script = autoAttempt
    ? `<script>
(function () {
  var intentUrl = ${js(intentUrl)};
  var returnUrl = ${js(returnUrl)};
  // Once per flow. sessionStorage survives the browser coming back to this
  // page (the user pressing 戻る, or the intent falling through), and firing
  // again then is how a loop starts. Keyed by the state so the *next* 連携
  // still gets its automatic attempt.
  var key = 'wop-return:' + ${js(carried.get('state') ?? '')};
  try {
    if (sessionStorage.getItem(key)) return;
    sessionStorage.setItem(key, '1');
  } catch (e) {}
  // Not from the load handler: Chromium is markedly more willing to follow a
  // navigation scheduled as a task than one performed while the page loads.
  setTimeout(function () {
    try { window.location.href = intentUrl; } catch (e) {}
  }, 0);
  // If the app took over, this document is hidden by now and must be left
  // alone — navigating a backgrounded tab pulls the browser back over the app.
  setTimeout(function () {
    if (document.visibilityState !== 'visible') return;
    try { window.location.href = returnUrl; } catch (e) {}
  }, 1200);
})();
</script>`
    : '';

  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>あと 1 タップ — Wake or Pay に戻る</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0;
         padding: 1.75rem 1.25rem 3rem;
         background: #1b1b1f; color: #e7e7ea; text-align: center; }
  h1 { font-size: 1.35rem; line-height: 1.5; margin: 0 0 0.35rem; }
  p { font-size: 1.05rem; line-height: 1.7; margin: 0.35rem 0; }
  p.lead { color: #b6b6c0; }
  p.hint { font-size: 0.95rem; color: #9a9aa4; margin-top: 2.25rem; }
  /* The button is the deliverable of this page, so it is the first thing on
     it and it is the size of a thumb. Everything else is below it. */
  a.button { display: block; margin: 1.5rem auto 0; max-width: 24rem;
             padding: 1.35rem 1.6rem; border-radius: 1.25rem;
             background: #5865f2; color: #fff; text-decoration: none;
             font-weight: 700; font-size: 1.35rem; letter-spacing: 0.02em;
             box-shadow: 0 6px 20px rgba(88, 101, 242, 0.45); }
  a.plain { display: block; margin-top: 1rem; color: #9aa0ff; font-size: 0.9rem; }
</style>
</head>
<body>
<h1>認証できました。あと 1 タップです。</h1>
<p class="lead">この画面のままでは連携は終わりません。<br>下のボタンでアプリに戻ってください。</p>
<a class="button" id="open" href="${intentHref}">Wake or Pay を開く</a>
<p class="hint">ボタンで戻らない場合はこちら</p>
<a class="plain" id="applink" href="${returnHref}">https のリンクで開く</a>
<a class="plain" id="scheme" href="${appHref}">wakeorpay:// で開く</a>
${script}
</body>
</html>
`;
}

function html(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      // The query holds a one-shot authorization code. Nothing caches this.
      'cache-control': 'no-store',
      'referrer-policy': 'no-referrer',
    },
  });
}

/**
 * The Digital Asset Links statement.
 *
 * Android fetches this over https, with no redirects allowed, and compares the
 * fingerprint against the certificate the installed APK is signed with. Match
 * and `https://…/discord/callback` opens the app directly; mismatch (or a
 * redirect, or the wrong content type) and it opens a browser instead, which
 * is the fallback page above rather than a failure.
 */
function assetLinks(env: Env): Response {
  const fingerprint = (env.ANDROID_CERT_SHA256 ?? '').trim();
  const statement = [
    {
      relation: [
        'delegate_permission/common.handle_all_urls',
      ],
      target: {
        namespace: 'android_app',
        package_name: ANDROID_PACKAGE,
        sha256_cert_fingerprints: fingerprint ? [fingerprint] : [],
      },
    },
  ];
  return new Response(JSON.stringify(statement), {
    status: 200,
    headers: {
      'content-type': 'application/json',
      // Android re-checks this periodically; a short cache is fine and a long
      // one makes a keystore change take days to take effect.
      'cache-control': 'public, max-age=300',
    },
  });
}

async function handleExchange(request: Request, env: Env): Promise<Response> {
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
  // Absent means the webhook flow: that is the only one that existed before
  // 「Discord で連携」 moved off the implicit grant, and an old build that
  // never sends the field still means exactly that.
  const mode = asString(body.mode) === 'identify' ? 'identify' : 'webhook';
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

  const accessToken = asString(token.access_token);

  if (mode === 'identify') {
    if (!accessToken) return error('no access token came back', 502);
    const me = await discordFetch(DISCORD_ME_URL, {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    if (!me) return error('could not reach Discord', 502);
    if (!me.ok) return error('Discord refused /users/@me', 502);
    let user: Record<string, unknown>;
    try {
      user = (await me.json()) as Record<string, unknown>;
    } catch {
      return error('Discord answered with something that is not JSON', 502);
    }
    const id = asString(user.id);
    // No id, no link: the id is the entire reason 「Discord で連携」 exists.
    if (!id) return error('no user came back from Discord', 502);
    const answer: IdentityExchangeResponse = {
      user: {
        id,
        username: asString(user.username),
        global_name: asString(user.global_name),
        avatar: asString(user.avatar),
      },
    };
    return json(answer);
  }

  const webhook = token.webhook as Record<string, unknown> | undefined;
  if (!webhook || !asString(webhook.url) || !asString(webhook.id)) {
    // No webhook means the authorization did not include webhook.incoming,
    // or the user picked nothing. Either way there is nothing to register.
    return error('no webhook came back from Discord', 502);
  }

  const guildId = asString(webhook.guild_id);
  const guildName = accessToken
    ? await fetchGuildName(accessToken, guildId)
    : null;

  const answer: WebhookExchangeResponse = {
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
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === ASSETLINKS_PATH) {
      if (request.method !== 'GET') return error('method not allowed', 405);
      return assetLinks(env);
    }

    if (url.pathname === CALLBACK_PATH || url.pathname === RETURN_PATH) {
      if (request.method !== 'GET') return error('method not allowed', 405);
      return html(
        callbackPage(
          url.searchParams,
          url.origin,
          // The return path is only ever reached because an automatic attempt
          // did not open the app. Attempting again from there is a loop.
          url.pathname === CALLBACK_PATH,
        ),
      );
    }

    if (url.pathname === EXCHANGE_PATH) return handleExchange(request, env);

    return error('not found', 404);
  },
};
