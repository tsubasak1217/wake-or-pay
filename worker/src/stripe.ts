/**
 * The smallest Stripe client that does this job.
 *
 * Deliberately **not** the `stripe` npm package: it drags in Node built-ins,
 * its own HTTP agent and a large surface, and everything Phase 1 needs is six
 * form-encoded REST calls. `fetch` plus `URLSearchParams` is the whole client.
 *
 * Two invariants hold for every call:
 *
 * - `Stripe-Version: 2024-06-20`. `POST /v1/ephemeral_keys` *refuses* a request
 *   without an explicit version header, and pinning it everywhere means a
 *   Stripe API upgrade cannot silently reshape a response this code parses.
 * - HTTP Basic auth with the secret key as the username and an empty password
 *   — Stripe's documented scheme. The key is never logged, never returned, and
 *   never put in a URL.
 */

/** The API version every request pins. */
export const STRIPE_VERSION = '2024-06-20';

const STRIPE_BASE = 'https://api.stripe.com';

/** How long Stripe is given to answer, per call. */
const STRIPE_TIMEOUT_MS = 15_000;

/** A Stripe refusal, or a failure to reach Stripe at all. */
export class StripeError extends Error {
  constructor(
    /** Stripe's HTTP status, or 0 when the request never completed. */
    readonly status: number,
    /** Stripe's `error.code`, when it sent one. */
    readonly code: string | null,
    message: string,
  ) {
    super(message);
    this.name = 'StripeError';
  }
}

/** The parts of a Stripe `card` PaymentMethod this Worker is allowed to keep. */
export interface StripeCard {
  brand: string;
  last4: string;
  expMonth: number;
  expYear: number;
}

export interface StripePaymentMethod {
  id: string;
  card?: {
    brand?: string;
    last4?: string;
    exp_month?: number;
    exp_year?: number;
  } | null;
}

export interface StripeSetupIntent {
  id: string;
  status?: string;
  customer?: string | { id?: string } | null;
  payment_method?: string | StripePaymentMethod | null;
}

export interface StripeCustomer {
  id: string;
}

export interface StripeEphemeralKey {
  id: string;
  secret?: string;
}

export class StripeClient {
  constructor(private readonly secretKey: string) {}

  private authHeaders(): Record<string, string> {
    return {
      // Basic <base64("sk_…:")> — the key is the username, password empty.
      authorization: `Basic ${btoa(`${this.secretKey}:`)}`,
      'Stripe-Version': STRIPE_VERSION,
    };
  }

  async post<T>(path: string, form: Record<string, string> = {}): Promise<T> {
    const body = new URLSearchParams(form).toString();
    return this.call<T>(path, {
      method: 'POST',
      headers: {
        ...this.authHeaders(),
        'content-type': 'application/x-www-form-urlencoded',
      },
      body,
    });
  }

  async get<T>(path: string): Promise<T> {
    return this.call<T>(path, { method: 'GET', headers: this.authHeaders() });
  }

  private async call<T>(path: string, init: RequestInit): Promise<T> {
    let response: Response;
    try {
      response = await fetch(`${STRIPE_BASE}${path}`, {
        ...init,
        signal: AbortSignal.timeout(STRIPE_TIMEOUT_MS),
      });
    } catch {
      throw new StripeError(0, null, 'could not reach Stripe');
    }

    let parsed: unknown;
    try {
      parsed = await response.json();
    } catch {
      parsed = null;
    }

    if (!response.ok) {
      const error = (parsed as { error?: { code?: string; type?: string } } | null)
        ?.error;
      throw new StripeError(
        response.status,
        // `code` is absent on some error types; `type` is the next best label.
        typeof error?.code === 'string'
          ? error.code
          : typeof error?.type === 'string'
            ? error.type
            : null,
        // Stripe's own message is *not* carried: it can echo request
        // parameters back, and none of that belongs in an answer to the app.
        `Stripe refused ${init.method ?? 'GET'} ${path}`,
      );
    }
    if (parsed === null) {
      throw new StripeError(response.status, null, 'Stripe answered with no JSON');
    }
    return parsed as T;
  }
}

/** The id out of a field Stripe returns either expanded or as a bare string. */
export function idOf(value: unknown): string | null {
  if (typeof value === 'string' && value) return value;
  if (value && typeof value === 'object') {
    const id = (value as { id?: unknown }).id;
    if (typeof id === 'string' && id) return id;
  }
  return null;
}

/** brand/last4/expiry out of an expanded PaymentMethod; null if incomplete. */
export function cardOf(pm: StripePaymentMethod | null | undefined): StripeCard | null {
  const card = pm?.card;
  if (!card) return null;
  const { brand, last4, exp_month: expMonth, exp_year: expYear } = card;
  if (
    typeof brand !== 'string' ||
    typeof last4 !== 'string' ||
    typeof expMonth !== 'number' ||
    typeof expYear !== 'number'
  ) {
    return null;
  }
  return { brand, last4, expMonth, expYear };
}
