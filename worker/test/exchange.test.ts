import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import worker, { type Env } from '../src/index';

/** The debug keystore's fingerprint, as wrangler.toml carries it. */
const FINGERPRINT =
  '11:3E:06:2F:19:63:A2:10:E1:AD:53:CE:73:E6:EF:02:D6:60:6F:AD:B6:01:EF:7F:C9:79:8E:1A:D0:78:BC:61';

const ENV: Env = {
  DISCORD_CLIENT_ID: '1542696296337506415',
  DISCORD_CLIENT_SECRET: 'shhh-this-never-leaves-the-worker',
  ALLOWED_ORIGINS: '',
  ANDROID_CERT_SHA256: FINGERPRINT,
  // The billing half's D1 binding. Nothing in this file reaches it — every
  // path here is the Discord Worker, which still keeps nothing at all.
  DB: null as unknown as D1Database,
};

/**
 * The redirect URI both flows now use — **https, on this Worker**.
 *
 * It used to be `wakeorpay://discord/callback`, and Discord refuses that for
 * this application: the authorize page ends at
 * `oauth2/error?error=invalid_request` with 「Redirect URI … is not supported
 * by client」 before the consent screen, so the app waited for a callback that
 * was never sent. Everything below asserts on the https form because that is
 * what the app now sends and what Discord now matches against.
 */
const REDIRECT_URI =
  'https://wake-or-pay-discord.wakeorpay.workers.dev/discord/callback';

/** A `/users/@me` body, for the `identify` mode. */
const ME_BODY = {
  id: '123456789012345678',
  username: 'hanako',
  global_name: '花子',
  avatar: 'abcdef',
  email: 'nope@example.com',
  discriminator: '0',
};

/** A token response of the shape `webhook.incoming` produces. */
const TOKEN_BODY = {
  access_token: 'ACCESS',
  refresh_token: 'REFRESH',
  token_type: 'Bearer',
  expires_in: 604800,
  scope: 'webhook.incoming identify',
  webhook: {
    id: '999',
    token: 'WEBHOOK_TOKEN',
    url: 'https://discord.com/api/webhooks/999/WEBHOOK_TOKEN',
    channel_id: '222',
    guild_id: '111',
    name: 'Wake or Pay',
    type: 1,
    application_id: '1542696296337506415',
    avatar: null,
  },
};

const GUILDS_BODY = [
  { id: '000', name: 'よその鯖' },
  { id: '111', name: 'みんなのサーバー' },
];

/** One fresh request. A different IP per test, so the rate limiter — which is
 *  module state and survives between tests — never crosses them over. */
let ipCounter = 0;
function exchangeRequest(
  body: unknown,
  init: { method?: string; origin?: string; path?: string; raw?: string } = {},
): Request {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
    'CF-Connecting-IP': `10.0.0.${++ipCounter % 250}`,
  };
  if (init.origin) headers.Origin = init.origin;
  return new Request(
    `https://worker.example.com${init.path ?? '/discord/exchange'}`,
    {
      method: init.method ?? 'POST',
      headers,
      body: init.raw ?? (init.method === 'GET' ? undefined : JSON.stringify(body)),
    },
  );
}

/** Answers the two Discord URLs the Worker calls, and records the calls. */
function stubDiscord(options: {
  tokenStatus?: number;
  tokenBody?: unknown;
  guildsStatus?: number;
  guildsBody?: unknown;
  meStatus?: number;
  meBody?: unknown;
  meRaw?: string;
  throwOn?: string;
}) {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  vi.stubGlobal('fetch', async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    if (options.throwOn && url.includes(options.throwOn)) {
      throw new TypeError('network');
    }
    if (url.includes('/oauth2/token')) {
      return new Response(
        JSON.stringify(options.tokenBody ?? TOKEN_BODY),
        { status: options.tokenStatus ?? 200 },
      );
    }
    // `/users/@me/guilds` and `/users/@me` differ by a suffix only, and
    // matching the shorter one first would answer the guild lookup with a
    // user object — a mistake that would make the webhook tests pass for the
    // wrong reason.
    if (url.endsWith('/guilds')) {
      return new Response(JSON.stringify(options.guildsBody ?? GUILDS_BODY), {
        status: options.guildsStatus ?? 200,
      });
    }
    return new Response(
      options.meRaw ?? JSON.stringify(options.meBody ?? ME_BODY),
      { status: options.meStatus ?? 200 },
    );
  });
  return calls;
}

beforeEach(() => {
  ipCounter += 17;
});
afterEach(() => vi.unstubAllGlobals());

describe('POST /discord/exchange', () => {
  it('returns the webhook and the guild name, and nothing else', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest({
        code: 'THE_CODE',
        redirect_uri: REDIRECT_URI,
      }),
      ENV,
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toEqual({
      webhook: {
        id: '999',
        url: 'https://discord.com/api/webhooks/999/WEBHOOK_TOKEN',
        channel_id: '222',
        guild_id: '111',
        name: 'Wake or Pay',
      },
      guild_name: 'みんなのサーバー',
      // Needs a bot or guilds.members.read; deliberately not asked for.
      channel_name: null,
    });
  });

  it('never returns the access or refresh token', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
      ENV,
    );
    const text = await response.text();
    // The whole reason the Worker exists is that these must not reach the app.
    expect(text).not.toContain('ACCESS');
    expect(text).not.toContain('REFRESH');
    expect(text).not.toContain('access_token');
    expect(text).not.toContain('refresh_token');
    expect(text).not.toContain(ENV.DISCORD_CLIENT_SECRET);
  });

  it('sends the client secret to Discord, form encoded', async () => {
    const calls = stubDiscord({});
    await worker.fetch(
      exchangeRequest({
        code: 'THE_CODE',
        redirect_uri: REDIRECT_URI,
      }),
      ENV,
    );

    const token = calls.find((c) => c.url.includes('/oauth2/token'))!;
    expect(token.init.method).toBe('POST');
    expect((token.init.headers as Record<string, string>)['content-type']).toBe(
      'application/x-www-form-urlencoded',
    );
    const form = new URLSearchParams(token.init.body as string);
    expect(form.get('grant_type')).toBe('authorization_code');
    expect(form.get('code')).toBe('THE_CODE');
    expect(form.get('redirect_uri')).toBe(REDIRECT_URI);
    expect(form.get('client_id')).toBe(ENV.DISCORD_CLIENT_ID);
    expect(form.get('client_secret')).toBe(ENV.DISCORD_CLIENT_SECRET);
    expect(form.get('code_verifier')).toBeNull();
  });

  it('passes a code_verifier through when the app sends one', async () => {
    const calls = stubDiscord({});
    await worker.fetch(
      exchangeRequest({
        code: 'C',
        redirect_uri: REDIRECT_URI,
        code_verifier: 'VERIFIER',
      }),
      ENV,
    );
    const form = new URLSearchParams(
      calls.find((c) => c.url.includes('/oauth2/token'))!.init.body as string,
    );
    expect(form.get('code_verifier')).toBe('VERIFIER');
  });

  it('falls back to a null guild name rather than failing', async () => {
    stubDiscord({ guildsStatus: 403 });
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
      ENV,
    );
    expect(response.status).toBe(200);
    const body = (await response.json()) as { guild_name: null; webhook: unknown };
    expect(body.guild_name).toBeNull();
    // The webhook is the part that matters; a missing label never costs it.
    expect(body.webhook).toBeTruthy();
  });

  it('is null when the guild is not in the list', async () => {
    stubDiscord({ guildsBody: [{ id: '000', name: 'よその鯖' }] });
    const body = (await (
      await worker.fetch(
        exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
        ENV,
      )
    ).json()) as { guild_name: string | null };
    expect(body.guild_name).toBeNull();
  });

  it('refuses a token response with no webhook in it', async () => {
    stubDiscord({ tokenBody: { access_token: 'A', scope: 'identify' } });
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
      ENV,
    );
    expect(response.status).toBe(502);
  });

  it("passes Discord's refusal status on", async () => {
    stubDiscord({ tokenStatus: 400, tokenBody: { error: 'invalid_grant' } });
    const response = await worker.fetch(
      exchangeRequest({ code: 'USED', redirect_uri: REDIRECT_URI }),
      ENV,
    );
    expect(response.status).toBe(400);
    // Discord's body echoes parameters back; none of it belongs in the answer.
    expect(await response.text()).not.toContain('invalid_grant');
  });

  it('answers 502 rather than throwing when Discord is unreachable', async () => {
    stubDiscord({ throwOn: '/oauth2/token' });
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
      ENV,
    );
    expect(response.status).toBe(502);
  });

  it('requires code and redirect_uri', async () => {
    stubDiscord({});
    expect(
      (await worker.fetch(exchangeRequest({ code: 'C' }), ENV)).status,
    ).toBe(400);
    expect(
      (
        await worker.fetch(
          exchangeRequest({ redirect_uri: REDIRECT_URI }),
          ENV,
        )
      ).status,
    ).toBe(400);
    expect(
      (await worker.fetch(exchangeRequest(null, { raw: 'not json' }), ENV))
        .status,
    ).toBe(400);
  });

  it('says so when the secret was never put on the Worker', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
      { ...ENV, DISCORD_CLIENT_SECRET: '' },
    );
    expect(response.status).toBe(500);
    // The most likely setup mistake, named where the deployer will see it.
    expect(await response.text()).toContain('DISCORD_CLIENT_SECRET');
  });
});

describe('what it refuses', () => {
  it('only answers POST on the one path', async () => {
    stubDiscord({});
    expect(
      (await worker.fetch(exchangeRequest({}, { method: 'GET' }), ENV)).status,
    ).toBe(405);
    expect(
      (await worker.fetch(exchangeRequest({}, { path: '/' }), ENV)).status,
    ).toBe(404);
  });

  it('refuses a browser origin that is not on the list', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest(
        { code: 'C', redirect_uri: REDIRECT_URI },
        { origin: 'https://evil.example' },
      ),
      ENV,
    );
    expect(response.status).toBe(403);
  });

  it('allows a listed origin', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest(
        { code: 'C', redirect_uri: REDIRECT_URI },
        { origin: 'https://ok.example' },
      ),
      { ...ENV, ALLOWED_ORIGINS: 'https://ok.example, https://also.example' },
    );
    expect(response.status).toBe(200);
  });

  it('allows a request with no Origin at all — that is the app', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI }),
      ENV,
    );
    expect(response.status).toBe(200);
  });

  it('rate limits one IP', async () => {
    stubDiscord({});
    const body = { code: 'C', redirect_uri: REDIRECT_URI };
    const one = (): Request => {
      const request = exchangeRequest(body);
      const headers = new Headers(request.headers);
      headers.set('CF-Connecting-IP', '203.0.113.99');
      return new Request(request.url, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
      });
    };

    const codes: number[] = [];
    for (let i = 0; i < 12; i++) {
      codes.push((await worker.fetch(one(), ENV)).status);
    }
    expect(codes.slice(0, 10).every((c) => c === 200)).toBe(true);
    expect(codes.at(-1)).toBe(429);
  });
});

describe('POST /discord/exchange, mode=identify', () => {
  /** 「Discord で連携」 asks for this, and only this. */
  const identify = (over: Record<string, unknown> = {}) =>
    exchangeRequest({
      code: 'THE_CODE',
      redirect_uri: REDIRECT_URI,
      mode: 'identify',
      ...over,
    });

  it('returns the four public fields of the user and nothing else', async () => {
    stubDiscord({ tokenBody: { access_token: 'ACCESS', scope: 'identify' } });
    const response = await worker.fetch(identify(), ENV);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      user: {
        id: '123456789012345678',
        username: 'hanako',
        global_name: '花子',
        avatar: 'abcdef',
      },
    });
  });

  it('never returns the token, and never the email', async () => {
    stubDiscord({ tokenBody: { access_token: 'ACCESS', refresh_token: 'REFRESH' } });
    const text = await (await worker.fetch(identify(), ENV)).text();
    expect(text).not.toContain('ACCESS');
    expect(text).not.toContain('REFRESH');
    expect(text).not.toContain('access_token');
    // `identify` does not grant the email and Discord does not send one — but
    // if it ever did, it has no business in this answer.
    expect(text).not.toContain('nope@example.com');
    expect(text).not.toContain(ENV.DISCORD_CLIENT_SECRET);
  });

  it('spends the token on /users/@me, not on /users/@me/guilds', async () => {
    const calls = stubDiscord({ tokenBody: { access_token: 'ACCESS' } });
    await worker.fetch(identify(), ENV);
    const me = calls.find((c) => c.url.endsWith('/users/@me'));
    expect(me).toBeTruthy();
    expect((me!.init.headers as Record<string, string>).authorization).toBe(
      'Bearer ACCESS',
    );
    // The guild lookup belongs to the webhook flow; identify has no guild.
    expect(calls.some((c) => c.url.endsWith('/guilds'))).toBe(false);
  });

  it('does not need a webhook in the token response', async () => {
    // The same body that is a 502 for the webhook flow is the normal case here.
    stubDiscord({ tokenBody: { access_token: 'A', scope: 'identify' } });
    expect((await worker.fetch(identify(), ENV)).status).toBe(200);
  });

  it('is 502 when /users/@me answers with no user', async () => {
    stubDiscord({
      tokenBody: { access_token: 'A' },
      meBody: { message: '401: Unauthorized' },
    });
    expect((await worker.fetch(identify(), ENV)).status).toBe(502);
  });

  it('is 502 when /users/@me refuses or is unreachable', async () => {
    stubDiscord({ tokenBody: { access_token: 'A' }, meStatus: 401 });
    expect((await worker.fetch(identify(), ENV)).status).toBe(502);

    stubDiscord({ tokenBody: { access_token: 'A' }, meRaw: '<html>portal</html>' });
    expect((await worker.fetch(identify(), ENV)).status).toBe(502);
  });

  it('an unknown mode is the webhook flow, as an old build means it', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: REDIRECT_URI, mode: 'nonsense' }),
      ENV,
    );
    const body = (await response.json()) as Record<string, unknown>;
    expect(body.webhook).toBeTruthy();
    expect(body.user).toBeUndefined();
  });
});

describe('GET /discord/callback', () => {
  const callback = (query: string) =>
    new Request(`https://worker.example.com/discord/callback${query}`);

  it('makes the tappable intent:// link the primary way back in', async () => {
    const response = await worker.fetch(callback('?code=THE_CODE&state=ST4TE'), ENV);

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('text/html');
    // A one-shot authorization code must not sit in any cache.
    expect(response.headers.get('cache-control')).toBe('no-store');

    const page = await response.text();
    // The button. A tap is a user gesture, which is the one thing Chromium
    // reliably honours for a non-http scheme — hence "primary".
    expect(page).toContain(
      '<a class="button" id="open" href="intent://discord/callback' +
        '?code=THE_CODE&amp;state=ST4TE' +
        '#Intent;scheme=wakeorpay;package=com.wakeorpay.wake_or_pay;',
    );
    expect(page).toContain('Wake or Pay を開く</a>');
    expect(page).toContain('S.browser_fallback_url=');
    // The other verified App Link path, both as a link and as the second
    // automatic attempt.
    expect(page).toContain(
      'href="https://worker.example.com/discord/callback/return' +
        '?code=THE_CODE&amp;state=ST4TE"',
    );
    expect(page).toContain(
      'var returnUrl = "https://worker.example.com/discord/callback/return' +
        '?code=THE_CODE&state=ST4TE"',
    );
    // And the custom scheme, still, as the last manual resort.
    expect(page).toContain(
      'href="wakeorpay://discord/callback?code=THE_CODE&amp;state=ST4TE"',
    );
    // The sentence and the hint, for when nothing automatic fired.
    // The page must not read as "done" — the user who saw the old one stopped
    // here, in the browser, believing the 連携 had finished.
    expect(page).toContain('認証できました。あと 1 タップです。');
    expect(page).toContain('この画面のままでは連携は終わりません。');
    expect(page).toContain('戻らない場合はこちら');
    // And the button comes first: everything else on the page is below it.
    expect(page.indexOf('id="open"')).toBeLessThan(page.indexOf('class="hint"'));
    expect(page.indexOf('id="open"')).toBeLessThan(page.indexOf('id="applink"'));
  });

  it('auto-attempts intent:// first, then the app-link path, once each', async () => {
    const page = await (
      await worker.fetch(callback('?code=C&state=ST4TE'), ENV)
    ).text();

    // Scheduled, not run from the load handler: Chromium drops a scripted
    // navigation to an unknown scheme performed while the page is loading.
    expect(page).toContain('setTimeout(function () {');
    expect(page).toContain('window.location.href = intentUrl;');
    expect(page).toContain('window.location.href = returnUrl;');
    // Never twice for one flow — that is how a navigation loop starts — and
    // never over an app that is already in front.
    expect(page).toContain("var key = 'wop-return:' + \"ST4TE\"");
    expect(page).toContain('sessionStorage.setItem(key');
    expect(page).toContain("document.visibilityState !== 'visible'");
    // The old, blocked attempt is gone.
    expect(page).not.toContain('location.replace(');
  });

  it('falls back to the return path, never to itself, when the app is absent', async () => {
    const page = await (
      await worker.fetch(callback('?code=C&state=S'), ENV)
    ).text();
    // browser_fallback_url pointing back at this page would auto-attempt,
    // fail again, and loop with a spent code in the address bar.
    expect(page).toContain(
      'S.browser_fallback_url=' +
        encodeURIComponent(
          'https://worker.example.com/discord/callback/return?code=C&state=S',
        ),
    );
  });

  it('carries a refusal across too', async () => {
    const page = await (
      await worker.fetch(
        callback('?error=access_denied&error_description=The+user+denied&state=S'),
        ENV,
      )
    ).text();
    expect(page).toContain('error=access_denied');
    expect(page).toContain('state=S');
    // The app decides what a refusal means; the page only carries it.
    expect(page).toContain('wakeorpay://discord/callback?');
  });

  it('drops anything that is not one of the four parameters', async () => {
    const page = await (
      await worker.fetch(callback('?code=C&state=S&evil=%3Cscript%3E'), ENV)
    ).text();
    expect(page).not.toContain('evil');
    expect(page).not.toContain('<script>e');
  });

  it('cannot be talked into closing its own script tag', async () => {
    const page = await (
      await worker.fetch(
        callback(`?code=${encodeURIComponent('a"</script><script>x')}&state=S`),
        ENV,
      )
    ).text();
    // The value is a JSON string literal with `<` escaped, so neither the
    // quote nor the tag can escape it.
    expect(page).not.toContain('</script><script>');
  });

  it('answers even with no parameters at all — that is the fallback link', async () => {
    const response = await worker.fetch(callback(''), ENV);
    expect(response.status).toBe(200);
    expect(await response.text()).toContain('wakeorpay://discord/callback');
  });

  it('is GET only', async () => {
    const response = await worker.fetch(
      new Request('https://worker.example.com/discord/callback', { method: 'POST' }),
      ENV,
    );
    expect(response.status).toBe(405);
  });
});

describe('GET /discord/callback/return', () => {
  const ret = (query: string) =>
    new Request(`https://worker.example.com/discord/callback/return${query}`);

  it('serves the same page with the button and the parameters intact', async () => {
    const response = await worker.fetch(ret('?code=THE_CODE&state=ST4TE'), ENV);

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('text/html');
    expect(response.headers.get('cache-control')).toBe('no-store');

    const page = await response.text();
    expect(page).toContain(
      'intent://discord/callback?code=THE_CODE&amp;state=ST4TE' +
        '#Intent;scheme=wakeorpay;package=com.wakeorpay.wake_or_pay;',
    );
    expect(page).toContain('Wake or Pay を開く</a>');
    expect(page).toContain('戻らない場合はこちら');
  });

  it('never auto-attempts — reaching it *is* the automatic attempt failing', async () => {
    const page = await (
      await worker.fetch(ret('?code=C&state=S'), ENV)
    ).text();
    // A page reached because a navigation did not open the app, navigating
    // again, is a loop. The only way on from here is the user's tap.
    expect(page).not.toContain('<script>');
    expect(page).not.toContain('setTimeout');
  });

  it('is GET only', async () => {
    const response = await worker.fetch(
      new Request('https://worker.example.com/discord/callback/return', {
        method: 'POST',
      }),
      ENV,
    );
    expect(response.status).toBe(405);
  });

  it('escapes a hostile value in every place it lands', async () => {
    const page = await (
      await worker.fetch(
        ret(`?code=${encodeURIComponent('"><img src=x onerror=alert(1)>')}&state=S`),
        ENV,
      )
    ).text();
    // URLSearchParams percent-encodes it before escapeHtml ever sees it, so
    // neither the quote nor the tag survives into the attribute.
    expect(page).not.toContain('<img');
    // The word can survive as literal text inside a value; the *attribute*
    // cannot, because the `=` that would make it one is percent-encoded.
    expect(page).not.toContain('onerror=');
    expect(page).toContain('%22%3E%3Cimg');
  });
});

describe('GET /.well-known/assetlinks.json', () => {
  it('vouches for the app with the signing certificate’s fingerprint', async () => {
    const response = await worker.fetch(
      new Request('https://worker.example.com/.well-known/assetlinks.json'),
      ENV,
    );

    expect(response.status).toBe(200);
    // Android insists on this exact content type and on no redirect.
    expect(response.headers.get('content-type')).toBe('application/json');

    expect(await response.json()).toEqual([
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: 'com.wakeorpay.wake_or_pay',
          sha256_cert_fingerprints: [FINGERPRINT],
        },
      },
    ]);
  });

  it('is an empty list rather than a lie when the var was never set', async () => {
    const response = await worker.fetch(
      new Request('https://worker.example.com/.well-known/assetlinks.json'),
      { ...ENV, ANDROID_CERT_SHA256: '' },
    );
    const body = (await response.json()) as Array<{
      target: { sha256_cert_fingerprints: string[] };
    }>;
    // Verification then fails and the callback lands on the fallback page,
    // which still works. A placeholder fingerprint would fail the same way
    // while looking configured.
    expect(body[0].target.sha256_cert_fingerprints).toEqual([]);
  });
});
