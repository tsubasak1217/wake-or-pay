/**
 * Phase 1 billing: register a device, hold a card, let go of it.
 *
 * **No money moves here.** Every route in this file exists to get a card into
 * Stripe under the user's own consent and to let the user take it back out
 * again. The charging (docs/BILLING_API.md, Phase 3) is not written yet, and
 * nothing in this file should be read as though it were.
 *
 * The contract is docs/BILLING_API.md and this file follows it literally:
 * paths, request shapes, response shapes, and the four error codes
 * (`bad_install_id`, `unauthorized`, `setup_not_succeeded`, `wrong_customer`).
 *
 * What never leaves this Worker: the Stripe secret key, the device token (the
 * one time it is minted it goes straight into the response body and is then
 * only a hash), and any card data beyond brand/last4/expiry.
 */

import { authenticate, hex, newDeviceToken, sha256Hex, timingSafeEqual } from './auth';
import type { Env } from './index';
import { rateLimited } from './ratelimit';
import {
  cardOf,
  idOf,
  StripeClient,
  StripeError,
  type StripeCustomer,
  type StripeEphemeralKey,
  type StripePaymentMethod,
  type StripeSetupIntent,
} from './stripe';
import {
  D1BillingStore,
  type BillingStore,
  type CardRow,
  type DeviceRow,
} from './store';

/** How far a webhook's timestamp may be from now. Stripe's own default. */
const WEBHOOK_TOLERANCE_S = 300;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      // Card state and one-shot tokens. Nothing here is ever cacheable.
      'cache-control': 'no-store',
    },
  });
}

/** The error shape the contract fixes: `{"error": "<snake_case_code>"}`. */
function fail(code: string, status: number): Response {
  return json({ error: code }, status);
}

function cardJson(card: CardRow | null) {
  if (!card) return null;
  return {
    brand: card.brand,
    last4: card.last4,
    expMonth: card.expMonth,
    expYear: card.expYear,
  };
}

async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const body = await request.json();
    return body && typeof body === 'object' ? (body as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

function asString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

/**
 * A Stripe failure, turned into something the app can act on.
 *
 * Stripe's own message is dropped: it echoes request parameters back, and one
 * of those parameters is a customer id belonging to somebody.
 */
function stripeFailure(err: unknown): Response {
  if (err instanceof StripeError) {
    return fail(err.status === 0 ? 'stripe_unreachable' : 'stripe_error', 502);
  }
  throw err;
}

/* -------------------------------------------------------------------------- */
/* Routing                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * @param storeOverride the tests' {@link MemoryBillingStore}. In production
 * this is absent and the store is D1's.
 */
export async function handleBilling(
  request: Request,
  env: Env,
  storeOverride?: BillingStore,
): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;

  // The webhook is checked before anything else needs configuration, because
  // its own answer to a missing secret must not be 200 (Stripe would treat a
  // 200 as delivered and never retry).
  if (path === '/v1/stripe/webhook') {
    if (method !== 'POST') return fail('method_not_allowed', 405);
    return handleWebhook(request, env, storeOverride);
  }

  if (!env.STRIPE_SECRET_KEY) return fail('stripe_not_configured', 500);
  const store = storeOverride ?? new D1BillingStore(env.DB);
  const stripe = new StripeClient(env.STRIPE_SECRET_KEY);

  if (path === '/v1/devices/register') {
    if (method !== 'POST') return fail('method_not_allowed', 405);
    if (rateLimited(clientIp(request), Date.now())) {
      return fail('too_many_requests', 429);
    }
    return handleRegister(request, store);
  }

  if (path === '/v1/billing/setup-intent') {
    if (method !== 'POST') return fail('method_not_allowed', 405);
    if (rateLimited(clientIp(request), Date.now())) {
      return fail('too_many_requests', 429);
    }
    const device = await authenticate(request, store);
    if (!device) return fail('unauthorized', 401);
    return handleSetupIntent(request, env, store, stripe, device);
  }

  if (path === '/v1/billing/card/confirm') {
    if (method !== 'POST') return fail('method_not_allowed', 405);
    const device = await authenticate(request, store);
    if (!device) return fail('unauthorized', 401);
    return handleConfirm(request, store, stripe, device);
  }

  if (path === '/v1/billing/card') {
    const device = await authenticate(request, store);
    if (!device) return fail('unauthorized', 401);
    if (method === 'GET') return handleGetCard(store, device);
    if (method === 'DELETE') return handleDeleteCard(store, stripe, device);
    return fail('method_not_allowed', 405);
  }

  return fail('not_found', 404);
}

function clientIp(request: Request): string {
  return request.headers.get('CF-Connecting-IP') ?? 'unknown';
}

/* -------------------------------------------------------------------------- */
/* POST /v1/devices/register                                                   */
/* -------------------------------------------------------------------------- */

async function handleRegister(
  request: Request,
  store: BillingStore,
): Promise<Response> {
  const body = await readJson(request);
  const installId = asString(body?.installId);
  if (!installId || !UUID_RE.test(installId)) return fail('bad_install_id', 400);

  const token = newDeviceToken();
  const now = new Date().toISOString();
  await store.registerDevice({
    id: installId,
    tokenHash: await sha256Hex(token),
    platform: asString(body?.platform),
    appVersion: asString(body?.appVersion),
    now,
  });
  // The one and only time the token itself exists outside the app.
  return json({ deviceToken: token });
}

/* -------------------------------------------------------------------------- */
/* POST /v1/billing/setup-intent                                               */
/* -------------------------------------------------------------------------- */

async function handleSetupIntent(
  request: Request,
  env: Env,
  store: BillingStore,
  stripe: StripeClient,
  device: DeviceRow,
): Promise<Response> {
  const body = await readJson(request);
  const consent = body?.consent as
    | { version?: unknown; acceptedAt?: unknown }
    | undefined;
  const version = typeof consent?.version === 'number' ? consent.version : null;
  const acceptedAt = asString(consent?.acceptedAt);
  // The consent *is* the mandate. Minting a SetupIntent without recording it
  // would leave a held card with no evidence the user ever agreed to it.
  if (version === null || !acceptedAt) return fail('bad_consent', 400);

  const now = new Date().toISOString();

  try {
    let customerId = device.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.post<StripeCustomer>('/v1/customers', {
        'metadata[install_id]': device.id,
      });
      customerId = customer.id;
      await store.setCustomerId(device.id, customerId, now);
    }

    const ephemeralKey = await stripe.post<StripeEphemeralKey>('/v1/ephemeral_keys', {
      customer: customerId,
    });
    const setupIntent = await stripe.post<
      StripeSetupIntent & { client_secret?: string }
    >('/v1/setup_intents', {
      customer: customerId,
      usage: 'off_session',
      'payment_method_types[]': 'card',
    });

    await store.addConsent({
      deviceId: device.id,
      version,
      acceptedAt,
      ip: request.headers.get('CF-Connecting-IP'),
      userAgent: request.headers.get('User-Agent'),
      now,
    });

    return json({
      customerId,
      ephemeralKeySecret: ephemeralKey.secret ?? null,
      setupIntentClientSecret: setupIntent.client_secret ?? null,
      publishableKey: env.STRIPE_PUBLISHABLE_KEY ?? null,
    });
  } catch (err) {
    return stripeFailure(err);
  }
}

/* -------------------------------------------------------------------------- */
/* POST /v1/billing/card/confirm                                               */
/* -------------------------------------------------------------------------- */

async function handleConfirm(
  request: Request,
  store: BillingStore,
  stripe: StripeClient,
  device: DeviceRow,
): Promise<Response> {
  const body = await readJson(request);
  const setupIntentId = asString(body?.setupIntentId);
  if (!setupIntentId) return fail('bad_setup_intent_id', 400);

  try {
    const setupIntent = await stripe.get<StripeSetupIntent>(
      `/v1/setup_intents/${encodeURIComponent(setupIntentId)}?expand[]=payment_method`,
    );
    const outcome = await adoptSetupIntent(store, stripe, device, setupIntent);
    if (typeof outcome === 'string') {
      // Ownership is checked before status, so a SetupIntent belonging to
      // somebody else never reveals whether it succeeded.
      if (outcome === 'wrong_customer') return fail('wrong_customer', 403);
      if (outcome === 'setup_not_succeeded') return fail('setup_not_succeeded', 409);
      return fail(outcome, 502);
    }
    return json({ card: cardJson(outcome) });
  } catch (err) {
    return stripeFailure(err);
  }
}

/**
 * The shared body of `confirm` and the `setup_intent.succeeded` webhook.
 *
 * Returns the stored card, or a failure code. It is deliberately idempotent:
 * the webhook is the insurance policy for an app that could not call confirm,
 * so both arriving is the *normal* case, not an error.
 */
async function adoptSetupIntent(
  store: BillingStore,
  stripe: StripeClient,
  device: DeviceRow,
  setupIntent: StripeSetupIntent,
): Promise<CardRow | 'wrong_customer' | 'setup_not_succeeded' | 'stripe_error'> {
  const customerId = idOf(setupIntent.customer);
  if (!device.stripeCustomerId || customerId !== device.stripeCustomerId) {
    return 'wrong_customer';
  }
  if (setupIntent.status !== 'succeeded') return 'setup_not_succeeded';

  const paymentMethodId = idOf(setupIntent.payment_method);
  if (!paymentMethodId) return 'stripe_error';
  const card = cardOf(
    typeof setupIntent.payment_method === 'object'
      ? (setupIntent.payment_method as StripePaymentMethod)
      : null,
  );
  if (!card) return 'stripe_error';

  await stripe.post(`/v1/customers/${encodeURIComponent(customerId)}`, {
    'invoice_settings[default_payment_method]': paymentMethodId,
  });

  // One device, one card. The old one is released at Stripe rather than left
  // attached to the customer where a later charge could still reach it.
  const previous = await store.card(device.id);
  if (previous && previous.paymentMethodId !== paymentMethodId) {
    await detachQuietly(stripe, previous.paymentMethodId);
  }

  const row: CardRow = {
    deviceId: device.id,
    paymentMethodId,
    brand: card.brand,
    last4: card.last4,
    expMonth: card.expMonth,
    expYear: card.expYear,
    createdAt: new Date().toISOString(),
  };
  await store.putCard(row);
  return row;
}

/**
 * Detach, and do not care if Stripe says it was already detached.
 *
 * The row is going away either way; a 400 here would otherwise leave the app
 * looking at a card the user has already asked to be rid of.
 */
async function detachQuietly(stripe: StripeClient, paymentMethodId: string) {
  try {
    await stripe.post(
      `/v1/payment_methods/${encodeURIComponent(paymentMethodId)}/detach`,
    );
  } catch (err) {
    if (!(err instanceof StripeError)) throw err;
  }
}

/* -------------------------------------------------------------------------- */
/* GET / DELETE /v1/billing/card                                               */
/* -------------------------------------------------------------------------- */

async function handleGetCard(
  store: BillingStore,
  device: DeviceRow,
): Promise<Response> {
  const [card, consent] = await Promise.all([
    store.card(device.id),
    store.latestConsent(device.id),
  ]);
  return json({ card: cardJson(card), consent });
}

async function handleDeleteCard(
  store: BillingStore,
  stripe: StripeClient,
  device: DeviceRow,
): Promise<Response> {
  const card = await store.card(device.id);
  if (card) {
    await detachQuietly(stripe, card.paymentMethodId);
    await store.deleteCard(device.id);
  }
  // 200 even with nothing to remove: 「解除」 that answers 404 reads as a
  // failure to the user, and the state they wanted is the state they have.
  // The consent row stays as history — see docs/BILLING_API.md.
  return json({ card: null });
}

/* -------------------------------------------------------------------------- */
/* POST /v1/stripe/webhook                                                     */
/* -------------------------------------------------------------------------- */

/**
 * Verify **before** parsing.
 *
 * The body is read as text, its signature is checked against
 * `STRIPE_WEBHOOK_SECRET`, and only then does any JSON parsing happen. An
 * unverified body is attacker-controlled input and nothing downstream of the
 * check should ever see one.
 */
async function handleWebhook(
  request: Request,
  env: Env,
  storeOverride?: BillingStore,
): Promise<Response> {
  if (!env.STRIPE_WEBHOOK_SECRET || !env.STRIPE_SECRET_KEY) {
    return fail('stripe_not_configured', 500);
  }
  const signature = request.headers.get('Stripe-Signature');
  const payload = await request.text();
  if (!signature || !(await verifySignature(payload, signature, env.STRIPE_WEBHOOK_SECRET))) {
    return fail('bad_signature', 400);
  }

  let event: { type?: unknown; data?: { object?: Record<string, unknown> } };
  try {
    event = JSON.parse(payload);
  } catch {
    return fail('bad_payload', 400);
  }

  const type = asString(event.type);
  const object = event.data?.object ?? {};
  const store = storeOverride ?? new D1BillingStore(env.DB);
  const stripe = new StripeClient(env.STRIPE_SECRET_KEY);

  try {
    if (type === 'setup_intent.succeeded') {
      const customerId = idOf(object.customer);
      const setupIntentId = asString(object.id);
      if (!customerId || !setupIntentId) return json({ received: true });
      const device = await store.deviceByCustomerId(customerId);
      // Not ours: another integration on the same Stripe account, or a
      // customer this Worker never created. Acknowledged, not acted on.
      if (!device) return json({ received: true });
      // Re-fetched rather than trusting the event body, because the event's
      // `payment_method` is a bare id and the card details are needed.
      const setupIntent = await stripe.get<StripeSetupIntent>(
        `/v1/setup_intents/${encodeURIComponent(setupIntentId)}?expand[]=payment_method`,
      );
      await adoptSetupIntent(store, stripe, device, setupIntent);
      return json({ received: true });
    }

    if (type === 'payment_method.detached') {
      const paymentMethodId = asString(object.id);
      if (paymentMethodId) {
        const card = await store.cardByPaymentMethodId(paymentMethodId);
        if (card) await store.deleteCard(card.deviceId);
      }
      return json({ received: true });
    }
  } catch (err) {
    // A 5xx tells Stripe to retry, which is what a transient Stripe or D1
    // failure deserves. A 200 here would lose the event for good.
    return stripeFailure(err);
  }

  // Everything else is acknowledged and ignored, per the contract.
  return json({ received: true, ignored: true });
}

/**
 * Stripe's `t=…,v1=…` scheme: HMAC-SHA256 over `"<t>.<payload>"`.
 *
 * A header may carry several `v1=` values during a secret rotation; any one
 * matching is a pass. The comparison is constant time, and the timestamp must
 * be within {@link WEBHOOK_TOLERANCE_S} so a captured-and-replayed delivery
 * stops working.
 */
export async function verifySignature(
  payload: string,
  header: string,
  secret: string,
  nowMs: number = Date.now(),
): Promise<boolean> {
  let timestamp: string | null = null;
  const signatures: string[] = [];
  for (const part of header.split(',')) {
    const index = part.indexOf('=');
    if (index < 0) continue;
    const key = part.slice(0, index).trim();
    const value = part.slice(index + 1).trim();
    if (key === 't') timestamp = value;
    else if (key === 'v1') signatures.push(value);
  }
  if (!timestamp || signatures.length === 0) return false;

  const seconds = Number(timestamp);
  if (!Number.isFinite(seconds)) return false;
  if (Math.abs(nowMs / 1000 - seconds) > WEBHOOK_TOLERANCE_S) return false;

  const expected = await hmacSha256Hex(secret, `${timestamp}.${payload}`);
  return signatures.some((candidate) => timingSafeEqual(candidate, expected));
}

export async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, encoder.encode(message));
  return hex(new Uint8Array(mac));
}
