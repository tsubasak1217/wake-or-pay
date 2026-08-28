import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import worker, { type Env } from '../src/index';

const ENV: Env = {
  DISCORD_CLIENT_ID: '1542696296337506415',
  DISCORD_CLIENT_SECRET: 'shhh-this-never-leaves-the-worker',
  ALLOWED_ORIGINS: '',
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
    return new Response(JSON.stringify(options.guildsBody ?? GUILDS_BODY), {
      status: options.guildsStatus ?? 200,
    });
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
        redirect_uri: 'wakeorpay://discord/callback',
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
      exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
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
        redirect_uri: 'wakeorpay://discord/callback',
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
    expect(form.get('redirect_uri')).toBe('wakeorpay://discord/callback');
    expect(form.get('client_id')).toBe(ENV.DISCORD_CLIENT_ID);
    expect(form.get('client_secret')).toBe(ENV.DISCORD_CLIENT_SECRET);
    expect(form.get('code_verifier')).toBeNull();
  });

  it('passes a code_verifier through when the app sends one', async () => {
    const calls = stubDiscord({});
    await worker.fetch(
      exchangeRequest({
        code: 'C',
        redirect_uri: 'wakeorpay://discord/callback',
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
      exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
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
        exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
        ENV,
      )
    ).json()) as { guild_name: string | null };
    expect(body.guild_name).toBeNull();
  });

  it('refuses a token response with no webhook in it', async () => {
    stubDiscord({ tokenBody: { access_token: 'A', scope: 'identify' } });
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
      ENV,
    );
    expect(response.status).toBe(502);
  });

  it("passes Discord's refusal status on", async () => {
    stubDiscord({ tokenStatus: 400, tokenBody: { error: 'invalid_grant' } });
    const response = await worker.fetch(
      exchangeRequest({ code: 'USED', redirect_uri: 'wakeorpay://discord/callback' }),
      ENV,
    );
    expect(response.status).toBe(400);
    // Discord's body echoes parameters back; none of it belongs in the answer.
    expect(await response.text()).not.toContain('invalid_grant');
  });

  it('answers 502 rather than throwing when Discord is unreachable', async () => {
    stubDiscord({ throwOn: '/oauth2/token' });
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
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
          exchangeRequest({ redirect_uri: 'wakeorpay://discord/callback' }),
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
      exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
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
        { code: 'C', redirect_uri: 'wakeorpay://discord/callback' },
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
        { code: 'C', redirect_uri: 'wakeorpay://discord/callback' },
        { origin: 'https://ok.example' },
      ),
      { ...ENV, ALLOWED_ORIGINS: 'https://ok.example, https://also.example' },
    );
    expect(response.status).toBe(200);
  });

  it('allows a request with no Origin at all — that is the app', async () => {
    stubDiscord({});
    const response = await worker.fetch(
      exchangeRequest({ code: 'C', redirect_uri: 'wakeorpay://discord/callback' }),
      ENV,
    );
    expect(response.status).toBe(200);
  });

  it('rate limits one IP', async () => {
    stubDiscord({});
    const body = { code: 'C', redirect_uri: 'wakeorpay://discord/callback' };
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
