import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { handleBilling, hmacSha256Hex } from '../src/billing';
import type { Env } from '../src/index';
import { MemoryBillingStore } from '../src/store';

const SECRET_KEY = 'sk_test_never_leaves_the_worker';
const WEBHOOK_SECRET = 'whsec_test_signing_secret';
const PUBLISHABLE_KEY = 'pk_test_public_and_fine_in_the_apk';

const ENV: Env = {
  DISCORD_CLIENT_ID: '1542696296337506415',
  DISCORD_CLIENT_SECRET: 'unused-here',
  STRIPE_SECRET_KEY: SECRET_KEY,
  STRIPE_WEBHOOK_SECRET: WEBHOOK_SECRET,
  STRIPE_PUBLISHABLE_KEY: PUBLISHABLE_KEY,
  // Every test injects a MemoryBillingStore, so the binding is never reached.
  DB: null as unknown as D1Database,
};

const INSTALL_ID = '3f1e0c5a-4d2b-4a7e-9c11-0b7d5e6a8f90';

/** A different IP per request: the rate limiter is module state and survives. */
let ipCounter = 0;
function req(
  path: string,
  init: {
    method?: string;
    body?: unknown;
    token?: string;
    raw?: string;
    headers?: Record<string, string>;
  } = {},
): Request {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
    'CF-Connecting-IP': `198.51.100.${++ipCounter % 250}`,
    'User-Agent': 'WakeOrPay/1.0.0+96 (Android)',
    ...init.headers,
  };
  if (init.token) headers.Authorization = `Bearer ${init.token}`;
  const method = init.method ?? 'POST';
  return new Request(`https://worker.example.com${path}`, {
    method,
    headers,
    body:
      init.raw ??
      (method === 'GET' || method === 'DELETE' || init.body === undefined
        ? undefined
        : JSON.stringify(init.body)),
  });
}

/* -------------------------------------------------------------------------- */
/* The Stripe stub                                                             */
/* -------------------------------------------------------------------------- */

interface StripeCall {
  method: string;
  path: string;
  auth: string;
  version: string;
  form: URLSearchParams;
}

const CARD = {
  brand: 'visa',
  last4: '4242',
  exp_month: 12,
  exp_year: 2030,
};

const PM = { id: 'pm_new', object: 'payment_method', card: CARD };

/** Answers every Stripe URL the Worker calls, and records the calls. */
function stubStripe(
  options: {
    setupIntent?: Record<string, unknown>;
    setupIntentStatus?: number;
    customerId?: string;
  } = {},
) {
  const calls: StripeCall[] = [];
  vi.stubGlobal('fetch', async (url: string, init: RequestInit) => {
    const path = url.replace('https://api.stripe.com', '');
    const headers = (init.headers ?? {}) as Record<string, string>;
    calls.push({
      method: init.method ?? 'GET',
      path,
      auth: headers.authorization ?? '',
      version: headers['Stripe-Version'] ?? '',
      form: new URLSearchParams((init.body as string) ?? ''),
    });

    const ok = (body: unknown, status = 200) =>
      new Response(JSON.stringify(body), { status });

    if (path.startsWith('/v1/setup_intents/')) {
      return ok(
        options.setupIntent ?? {
          id: 'seti_1',
          status: 'succeeded',
          customer: options.customerId ?? 'cus_1',
          payment_method: PM,
        },
        options.setupIntentStatus ?? 200,
      );
    }
    if (path === '/v1/setup_intents') {
      return ok({ id: 'seti_1', client_secret: 'seti_1_secret_abc' });
    }
    if (path === '/v1/ephemeral_keys') {
      return ok({ id: 'ephkey_1', secret: 'ek_test_123' });
    }
    if (path === '/v1/customers') return ok({ id: options.customerId ?? 'cus_1' });
    if (path.startsWith('/v1/customers/')) {
      return ok({ id: options.customerId ?? 'cus_1' });
    }
    if (path.endsWith('/detach')) return ok({ id: 'pm_old', customer: null });
    return ok({});
  });
  return calls;
}

const store = () => new MemoryBillingStore();

async function register(
  db: MemoryBillingStore,
  installId = INSTALL_ID,
): Promise<string> {
  const response = await handleBilling(
    req('/v1/devices/register', {
      body: { installId, platform: 'android', appVersion: '1.0.0+96' },
    }),
    ENV,
    db,
  );
  expect(response.status).toBe(200);
  const body = (await response.json()) as { deviceToken: string };
  return body.deviceToken;
}

/** Register, then take a SetupIntent so the device has a Stripe customer. */
async function registered(db: MemoryBillingStore): Promise<string> {
  const token = await register(db);
  const response = await handleBilling(
    req('/v1/billing/setup-intent', {
      token,
      body: { consent: { version: 1, acceptedAt: '2026-08-29T00:00:00Z' } },
    }),
    ENV,
    db,
  );
  expect(response.status).toBe(200);
  return token;
}

beforeEach(() => {
  ipCounter += 23;
  stubStripe();
});
afterEach(() => vi.unstubAllGlobals());

/* -------------------------------------------------------------------------- */

describe('POST /v1/devices/register', () => {
  it('returns an opaque token and never stores the token itself', async () => {
    const db = store();
    const token = await register(db);

    expect(token.length).toBeGreaterThanOrEqual(43);
    // base64url: no +, /, or padding, so it survives a header and a URL.
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
    const device = db.devices.get(INSTALL_ID)!;
    expect(device.tokenHash).toMatch(/^[0-9a-f]{64}$/);
    expect(device.tokenHash).not.toContain(token);
    expect(device.platform).toBe('android');
    expect(device.appVersion).toBe('1.0.0+96');
  });

  it('re-registering replaces the hash but keeps the Stripe customer', async () => {
    const db = store();
    const first = await registered(db);
    const customerId = db.devices.get(INSTALL_ID)!.stripeCustomerId;
    expect(customerId).toBe('cus_1');
    const firstHash = db.devices.get(INSTALL_ID)!.tokenHash;

    const second = await register(db);
    expect(second).not.toBe(first);
    const device = db.devices.get(INSTALL_ID)!;
    expect(device.tokenHash).not.toBe(firstHash);
    // The recovery path must not orphan a card the user believes is held.
    expect(device.stripeCustomerId).toBe(customerId);

    // And the old token stops working the moment the new one exists.
    expect(
      (
        await handleBilling(
          req('/v1/billing/card', { method: 'GET', token: first }),
          ENV,
          db,
        )
      ).status,
    ).toBe(401);
    expect(
      (
        await handleBilling(
          req('/v1/billing/card', { method: 'GET', token: second }),
          ENV,
          db,
        )
      ).status,
    ).toBe(200);
  });

  it('refuses an installId that is not a UUID', async () => {
    const db = store();
    for (const installId of ['', 'not-a-uuid', '../../etc', '12345']) {
      const response = await handleBilling(
        req('/v1/devices/register', { body: { installId } }),
        ENV,
        db,
      );
      expect(response.status).toBe(400);
      expect(await response.json()).toEqual({ error: 'bad_install_id' });
    }
    expect(db.devices.size).toBe(0);
  });

  it('rate limits one IP', async () => {
    const db = store();
    const one = () =>
      new Request('https://worker.example.com/v1/devices/register', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'CF-Connecting-IP': '203.0.113.7',
        },
        body: JSON.stringify({ installId: INSTALL_ID }),
      });
    const codes: number[] = [];
    for (let i = 0; i < 12; i++) {
      codes.push((await handleBilling(one(), ENV, db)).status);
    }
    expect(codes.slice(0, 10).every((c) => c === 200)).toBe(true);
    expect(codes.at(-1)).toBe(429);
  });
});

describe('authentication', () => {
  it('every /v1/billing/* path is 401 without a valid bearer token', async () => {
    const db = store();
    await register(db);
    const cases: Array<[string, string]> = [
      ['POST', '/v1/billing/setup-intent'],
      ['POST', '/v1/billing/card/confirm'],
      ['GET', '/v1/billing/card'],
      ['DELETE', '/v1/billing/card'],
    ];
    for (const [method, path] of cases) {
      for (const token of [undefined, 'nonsense', '']) {
        const response = await handleBilling(
          req(path, { method, token, body: {} }),
          ENV,
          db,
        );
        expect(response.status, `${method} ${path}`).toBe(401);
        expect(await response.json()).toEqual({ error: 'unauthorized' });
      }
    }
  });
});

describe('POST /v1/billing/setup-intent', () => {
  it('creates the customer once and returns the four fields', async () => {
    const db = store();
    const token = await register(db);
    const calls = stubStripe();

    const response = await handleBilling(
      req('/v1/billing/setup-intent', {
        token,
        body: { consent: { version: 1, acceptedAt: '2026-08-29T00:00:00Z' } },
      }),
      ENV,
      db,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      customerId: 'cus_1',
      ephemeralKeySecret: 'ek_test_123',
      setupIntentClientSecret: 'seti_1_secret_abc',
      publishableKey: PUBLISHABLE_KEY,
    });

    const customer = calls.find((c) => c.path === '/v1/customers')!;
    expect(customer.method).toBe('POST');
    expect(customer.auth).toBe(`Basic ${btoa(`${SECRET_KEY}:`)}`);
    // ephemeral_keys is *refused* without an explicit version header.
    expect(customer.version).toBe('2024-06-20');
    expect(customer.form.get('metadata[install_id]')).toBe(INSTALL_ID);

    const ephemeral = calls.find((c) => c.path === '/v1/ephemeral_keys')!;
    expect(ephemeral.form.get('customer')).toBe('cus_1');
    expect(ephemeral.version).toBe('2024-06-20');

    const setupIntent = calls.find((c) => c.path === '/v1/setup_intents')!;
    expect(setupIntent.form.get('customer')).toBe('cus_1');
    expect(setupIntent.form.get('usage')).toBe('off_session');
    expect(setupIntent.form.get('payment_method_types[]')).toBe('card');

    // A second call reuses the customer rather than making another.
    const again = stubStripe();
    await handleBilling(
      req('/v1/billing/setup-intent', {
        token,
        body: { consent: { version: 1, acceptedAt: '2026-08-29T01:00:00Z' } },
      }),
      ENV,
      db,
    );
    expect(again.some((c) => c.path === '/v1/customers')).toBe(false);
  });

  it('records the consent with the request IP and User-Agent', async () => {
    const db = store();
    const token = await register(db);
    await handleBilling(
      req('/v1/billing/setup-intent', {
        token,
        body: { consent: { version: 1, acceptedAt: '2026-08-29T00:00:00Z' } },
        headers: { 'CF-Connecting-IP': '198.51.100.42' },
      }),
      ENV,
      db,
    );
    expect(db.consents).toHaveLength(1);
    expect(db.consents[0]).toMatchObject({
      deviceId: INSTALL_ID,
      version: 1,
      acceptedAt: '2026-08-29T00:00:00Z',
      ip: '198.51.100.42',
      userAgent: 'WakeOrPay/1.0.0+96 (Android)',
    });
  });

  it('refuses to mint a SetupIntent with no consent behind it', async () => {
    const db = store();
    const token = await register(db);
    const calls = stubStripe();
    const response = await handleBilling(
      req('/v1/billing/setup-intent', { token, body: {} }),
      ENV,
      db,
    );
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: 'bad_consent' });
    expect(calls).toHaveLength(0);
  });

  it('never leaks the secret key into the response', async () => {
    const db = store();
    const token = await register(db);
    const text = await (
      await handleBilling(
        req('/v1/billing/setup-intent', {
          token,
          body: { consent: { version: 1, acceptedAt: '2026-08-29T00:00:00Z' } },
        }),
        ENV,
        db,
      )
    ).text();
    expect(text).not.toContain(SECRET_KEY);
    expect(text).not.toContain(WEBHOOK_SECRET);
  });
});

describe('POST /v1/billing/card/confirm', () => {
  it('stores the card, sets it as default, and detaches the previous one', async () => {
    const db = store();
    const token = await registered(db);
    // A card is already held; confirming a new one must release the old.
    await db.putCard({
      deviceId: INSTALL_ID,
      paymentMethodId: 'pm_old',
      brand: 'mastercard',
      last4: '4444',
      expMonth: 1,
      expYear: 2027,
      createdAt: '2026-01-01T00:00:00Z',
    });

    const calls = stubStripe();
    const response = await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      card: { brand: 'visa', last4: '4242', expMonth: 12, expYear: 2030 },
    });

    const fetched = calls.find((c) => c.path.startsWith('/v1/setup_intents/seti_1'))!;
    expect(fetched.method).toBe('GET');
    // The card details are only on the *expanded* payment method.
    expect(fetched.path).toContain('expand[]=payment_method');

    const customer = calls.find((c) => c.path === '/v1/customers/cus_1')!;
    expect(customer.method).toBe('POST');
    expect(customer.form.get('invoice_settings[default_payment_method]')).toBe(
      'pm_new',
    );

    const detach = calls.find((c) => c.path.endsWith('/detach'))!;
    expect(detach.path).toBe('/v1/payment_methods/pm_old/detach');
    expect(detach.method).toBe('POST');

    expect(db.cards.get(INSTALL_ID)).toMatchObject({
      paymentMethodId: 'pm_new',
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
    });
  });

  it('does not detach when the same card is confirmed twice', async () => {
    const db = store();
    const token = await registered(db);
    await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    const calls = stubStripe();
    const response = await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    // Detaching the card that was just confirmed would leave the user with none.
    expect(calls.some((c) => c.path.endsWith('/detach'))).toBe(false);
  });

  it('is 409 when the SetupIntent did not succeed', async () => {
    const db = store();
    const token = await registered(db);
    stubStripe({
      setupIntent: {
        id: 'seti_1',
        status: 'requires_payment_method',
        customer: 'cus_1',
        payment_method: null,
      },
    });
    const response = await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: 'setup_not_succeeded' });
    expect(db.cards.size).toBe(0);
  });

  it("is 403 for another customer's SetupIntent", async () => {
    const db = store();
    const token = await registered(db);
    stubStripe({
      setupIntent: {
        id: 'seti_x',
        status: 'succeeded',
        customer: 'cus_somebody_else',
        payment_method: PM,
      },
    });
    const response = await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_x' } }),
      ENV,
      db,
    );
    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: 'wrong_customer' });
    expect(db.cards.size).toBe(0);
  });

  it('is 403 when the device has no customer at all yet', async () => {
    const db = store();
    // Registered but never through setup-intent: there is nothing to own.
    const token = await register(db);
    const response = await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    expect(response.status).toBe(403);
  });
});

describe('GET and DELETE /v1/billing/card', () => {
  it('is null card and null consent before anything happens', async () => {
    const db = store();
    const token = await register(db);
    const response = await handleBilling(
      req('/v1/billing/card', { method: 'GET', token }),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ card: null, consent: null });
  });

  it('returns the held card and the latest consent', async () => {
    const db = store();
    const token = await registered(db);
    await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    const body = await (
      await handleBilling(req('/v1/billing/card', { method: 'GET', token }), ENV, db)
    ).json();
    expect(body).toEqual({
      card: { brand: 'visa', last4: '4242', expMonth: 12, expYear: 2030 },
      consent: { version: 1, acceptedAt: '2026-08-29T00:00:00Z' },
    });
  });

  it('detaches at Stripe and drops the row, keeping the consent as history', async () => {
    const db = store();
    const token = await registered(db);
    await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );

    const calls = stubStripe();
    const response = await handleBilling(
      req('/v1/billing/card', { method: 'DELETE', token }),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ card: null });
    expect(calls.find((c) => c.path.endsWith('/detach'))!.path).toBe(
      '/v1/payment_methods/pm_new/detach',
    );
    expect(db.cards.size).toBe(0);
    // 解除 removes the card, not the evidence that consent was once given.
    expect(db.consents).toHaveLength(1);
  });

  it('is 200 with nothing to remove', async () => {
    const db = store();
    const token = await register(db);
    const calls = stubStripe();
    const response = await handleBilling(
      req('/v1/billing/card', { method: 'DELETE', token }),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ card: null });
    expect(calls).toHaveLength(0);
  });
});

/* -------------------------------------------------------------------------- */
/* The webhook                                                                 */
/* -------------------------------------------------------------------------- */

/** Stripe's `t=…,v1=…`, built from the test's side of the same algorithm. */
async function signed(
  payload: string,
  secret = WEBHOOK_SECRET,
  timestampS = Math.floor(Date.now() / 1000),
): Promise<string> {
  const v1 = await hmacSha256Hex(secret, `${timestampS}.${payload}`);
  return `t=${timestampS},v1=${v1}`;
}

function webhookRequest(payload: string, signature: string | null): Request {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (signature) headers['Stripe-Signature'] = signature;
  return new Request('https://worker.example.com/v1/stripe/webhook', {
    method: 'POST',
    headers,
    body: payload,
  });
}

describe('POST /v1/stripe/webhook', () => {
  const event = (type: string, object: Record<string, unknown>) =>
    JSON.stringify({ id: 'evt_1', type, data: { object } });

  it('refuses a missing, malformed, stale or forged signature', async () => {
    const db = store();
    const payload = event('setup_intent.succeeded', {
      id: 'seti_1',
      customer: 'cus_1',
    });

    const bad = [
      null,
      'nonsense',
      't=1,v1=deadbeef',
      // Right secret, wrong body — the signature is over the payload.
      await signed('{"id":"evt_other"}'),
      // Right body, wrong secret.
      await signed(payload, 'whsec_not_the_one'),
      // Right body and secret, but six minutes old: outside the 300 s window,
      // which is what stops a captured delivery being replayed.
      await signed(payload, WEBHOOK_SECRET, Math.floor(Date.now() / 1000) - 360),
    ];
    for (const signature of bad) {
      const response = await handleBilling(
        webhookRequest(payload, signature),
        ENV,
        db,
      );
      expect(response.status, String(signature)).toBe(400);
      expect(await response.json()).toEqual({ error: 'bad_signature' });
    }
    expect(db.cards.size).toBe(0);
  });

  it('stores the card on a valid setup_intent.succeeded', async () => {
    const db = store();
    await registered(db);
    const payload = event('setup_intent.succeeded', {
      id: 'seti_1',
      object: 'setup_intent',
      status: 'succeeded',
      customer: 'cus_1',
      payment_method: 'pm_new',
    });

    const calls = stubStripe();
    const response = await handleBilling(
      webhookRequest(payload, await signed(payload)),
      ENV,
      db,
    );

    expect(response.status).toBe(200);
    // Re-fetched, expanded: the event body carries only the id of the method.
    expect(
      calls.some((c) => c.path.startsWith('/v1/setup_intents/seti_1?expand')),
    ).toBe(true);
    expect(db.cards.get(INSTALL_ID)).toMatchObject({
      paymentMethodId: 'pm_new',
      brand: 'visa',
      last4: '4242',
    });
  });

  it('removes the card on payment_method.detached', async () => {
    const db = store();
    const token = await registered(db);
    await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    expect(db.cards.size).toBe(1);

    const payload = event('payment_method.detached', {
      id: 'pm_new',
      object: 'payment_method',
    });
    const response = await handleBilling(
      webhookRequest(payload, await signed(payload)),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(db.cards.size).toBe(0);
  });

  it('ignores a detach for a payment method it never held', async () => {
    const db = store();
    const token = await registered(db);
    await handleBilling(
      req('/v1/billing/card/confirm', { token, body: { setupIntentId: 'seti_1' } }),
      ENV,
      db,
    );
    const payload = event('payment_method.detached', { id: 'pm_someone_else' });
    const response = await handleBilling(
      webhookRequest(payload, await signed(payload)),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(db.cards.size).toBe(1);
  });

  it('acknowledges every other event without acting on it', async () => {
    const db = store();
    await registered(db);
    const payload = event('invoice.paid', { id: 'in_1', customer: 'cus_1' });
    const calls = stubStripe();
    const response = await handleBilling(
      webhookRequest(payload, await signed(payload)),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ received: true, ignored: true });
    expect(calls).toHaveLength(0);
  });

  it('ignores a setup_intent for a customer this Worker never created', async () => {
    const db = store();
    await registered(db);
    const payload = event('setup_intent.succeeded', {
      id: 'seti_z',
      customer: 'cus_unknown',
    });
    const calls = stubStripe();
    const response = await handleBilling(
      webhookRequest(payload, await signed(payload)),
      ENV,
      db,
    );
    expect(response.status).toBe(200);
    expect(calls).toHaveLength(0);
    expect(db.cards.size).toBe(0);
  });

  it('is 500, not 200, when the signing secret was never put on the Worker', async () => {
    const db = store();
    const payload = event('setup_intent.succeeded', { id: 'seti_1' });
    const response = await handleBilling(
      webhookRequest(payload, await signed(payload)),
      { ...ENV, STRIPE_WEBHOOK_SECRET: '' },
      db,
    );
    // A 200 would tell Stripe the event was delivered and it would never retry.
    expect(response.status).toBe(500);
  });
});

describe('what the billing router refuses', () => {
  it('is 404 for an unknown /v1 path and 405 for the wrong method', async () => {
    const db = store();
    expect(
      (await handleBilling(req('/v1/nope', { body: {} }), ENV, db)).status,
    ).toBe(404);
    expect(
      (
        await handleBilling(
          req('/v1/devices/register', { method: 'GET' }),
          ENV,
          db,
        )
      ).status,
    ).toBe(405);
    expect(
      (
        await handleBilling(
          req('/v1/stripe/webhook', { method: 'GET' }),
          ENV,
          db,
        )
      ).status,
    ).toBe(405);
  });

  it('says so when the secret key was never put on the Worker', async () => {
    const db = store();
    const response = await handleBilling(
      req('/v1/devices/register', { body: { installId: INSTALL_ID } }),
      { ...ENV, STRIPE_SECRET_KEY: '' },
      db,
    );
    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: 'stripe_not_configured' });
  });

  it('answers 502 rather than throwing when Stripe is unreachable', async () => {
    const db = store();
    const token = await register(db);
    vi.stubGlobal('fetch', async () => {
      throw new TypeError('network');
    });
    const response = await handleBilling(
      req('/v1/billing/setup-intent', {
        token,
        body: { consent: { version: 1, acceptedAt: '2026-08-29T00:00:00Z' } },
      }),
      ENV,
      db,
    );
    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: 'stripe_unreachable' });
  });
});
