/**
 * Everything the billing endpoints keep, behind one interface.
 *
 * Two implementations: {@link D1BillingStore} over the `DB` binding, and
 * {@link MemoryBillingStore} for the tests. The interface exists so the route
 * tests can run without a D1 — not as speculative generality; there is exactly
 * one production implementation and there is meant to be exactly one.
 *
 * What is **not** here, on purpose: the device token (only its SHA-256 hex),
 * the card number, and anything Stripe already holds. See docs/BILLING_API.md.
 */

export interface DeviceRow {
  /** `installId`, a UUID the app generates once and keeps. */
  id: string;
  /** sha256(deviceToken), hex. The token itself is never stored. */
  tokenHash: string;
  stripeCustomerId: string | null;
  platform: string | null;
  appVersion: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CardRow {
  deviceId: string;
  paymentMethodId: string;
  brand: string;
  last4: string;
  expMonth: number;
  expYear: number;
  createdAt: string;
}

export interface ConsentRow {
  version: number;
  acceptedAt: string;
}

export interface BillingStore {
  deviceById(id: string): Promise<DeviceRow | null>;
  deviceByTokenHash(tokenHash: string): Promise<DeviceRow | null>;
  deviceByCustomerId(customerId: string): Promise<DeviceRow | null>;

  /**
   * Register or re-register one install.
   *
   * A second call for the same `installId` **replaces the token hash and keeps
   * the Stripe customer** — that is the recovery path for an app that lost its
   * token but not its install id, and losing the customer there would orphan a
   * card the user believes is still held.
   */
  registerDevice(input: {
    id: string;
    tokenHash: string;
    platform: string | null;
    appVersion: string | null;
    now: string;
  }): Promise<DeviceRow>;

  setCustomerId(deviceId: string, customerId: string, now: string): Promise<void>;

  /** Consents are append-only: the mandate's history is the evidence. */
  addConsent(input: {
    deviceId: string;
    version: number;
    acceptedAt: string;
    ip: string | null;
    userAgent: string | null;
    now: string;
  }): Promise<void>;
  latestConsent(deviceId: string): Promise<ConsentRow | null>;

  card(deviceId: string): Promise<CardRow | null>;
  cardByPaymentMethodId(paymentMethodId: string): Promise<CardRow | null>;
  /** One device, one card: this replaces whatever was there. */
  putCard(card: CardRow): Promise<void>;
  deleteCard(deviceId: string): Promise<void>;
}

/* -------------------------------------------------------------------------- */

export class D1BillingStore implements BillingStore {
  constructor(private readonly db: D1Database) {}

  async deviceById(id: string): Promise<DeviceRow | null> {
    return this.device('SELECT * FROM devices WHERE id = ?', id);
  }

  async deviceByTokenHash(tokenHash: string): Promise<DeviceRow | null> {
    return this.device('SELECT * FROM devices WHERE token_hash = ?', tokenHash);
  }

  async deviceByCustomerId(customerId: string): Promise<DeviceRow | null> {
    return this.device(
      'SELECT * FROM devices WHERE stripe_customer_id = ?',
      customerId,
    );
  }

  private async device(sql: string, key: string): Promise<DeviceRow | null> {
    const row = await this.db.prepare(sql).bind(key).first<Record<string, unknown>>();
    return row ? toDevice(row) : null;
  }

  async registerDevice(input: {
    id: string;
    tokenHash: string;
    platform: string | null;
    appVersion: string | null;
    now: string;
  }): Promise<DeviceRow> {
    await this.db
      .prepare(
        `INSERT INTO devices
           (id, token_hash, stripe_customer_id, platform, app_version,
            created_at, updated_at)
         VALUES (?, ?, NULL, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           token_hash = excluded.token_hash,
           platform = excluded.platform,
           app_version = excluded.app_version,
           updated_at = excluded.updated_at`,
      )
      .bind(
        input.id,
        input.tokenHash,
        input.platform,
        input.appVersion,
        input.now,
        input.now,
      )
      .run();
    const row = await this.deviceById(input.id);
    if (!row) throw new Error('device vanished immediately after upsert');
    return row;
  }

  async setCustomerId(
    deviceId: string,
    customerId: string,
    now: string,
  ): Promise<void> {
    await this.db
      .prepare('UPDATE devices SET stripe_customer_id = ?, updated_at = ? WHERE id = ?')
      .bind(customerId, now, deviceId)
      .run();
  }

  async addConsent(input: {
    deviceId: string;
    version: number;
    acceptedAt: string;
    ip: string | null;
    userAgent: string | null;
    now: string;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO consents
           (device_id, version, accepted_at, ip, user_agent, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        input.deviceId,
        input.version,
        input.acceptedAt,
        input.ip,
        input.userAgent,
        input.now,
      )
      .run();
  }

  async latestConsent(deviceId: string): Promise<ConsentRow | null> {
    const row = await this.db
      .prepare(
        `SELECT version, accepted_at FROM consents
          WHERE device_id = ? ORDER BY id DESC LIMIT 1`,
      )
      .bind(deviceId)
      .first<{ version: number; accepted_at: string }>();
    return row ? { version: Number(row.version), acceptedAt: row.accepted_at } : null;
  }

  async card(deviceId: string): Promise<CardRow | null> {
    const row = await this.db
      .prepare('SELECT * FROM cards WHERE device_id = ?')
      .bind(deviceId)
      .first<Record<string, unknown>>();
    return row ? toCard(row) : null;
  }

  async cardByPaymentMethodId(paymentMethodId: string): Promise<CardRow | null> {
    const row = await this.db
      .prepare('SELECT * FROM cards WHERE payment_method_id = ?')
      .bind(paymentMethodId)
      .first<Record<string, unknown>>();
    return row ? toCard(row) : null;
  }

  async putCard(card: CardRow): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO cards
           (device_id, payment_method_id, brand, last4, exp_month, exp_year,
            created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(device_id) DO UPDATE SET
           payment_method_id = excluded.payment_method_id,
           brand = excluded.brand,
           last4 = excluded.last4,
           exp_month = excluded.exp_month,
           exp_year = excluded.exp_year,
           created_at = excluded.created_at`,
      )
      .bind(
        card.deviceId,
        card.paymentMethodId,
        card.brand,
        card.last4,
        card.expMonth,
        card.expYear,
        card.createdAt,
      )
      .run();
  }

  async deleteCard(deviceId: string): Promise<void> {
    await this.db.prepare('DELETE FROM cards WHERE device_id = ?').bind(deviceId).run();
  }
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function toDevice(row: Record<string, unknown>): DeviceRow {
  return {
    id: String(row.id),
    tokenHash: String(row.token_hash),
    stripeCustomerId: str(row.stripe_customer_id),
    platform: str(row.platform),
    appVersion: str(row.app_version),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  };
}

function toCard(row: Record<string, unknown>): CardRow {
  return {
    deviceId: String(row.device_id),
    paymentMethodId: String(row.payment_method_id),
    brand: String(row.brand),
    last4: String(row.last4),
    expMonth: Number(row.exp_month),
    expYear: Number(row.exp_year),
    createdAt: String(row.created_at),
  };
}

/* -------------------------------------------------------------------------- */

/** The same contract, in three Maps. Tests only. */
export class MemoryBillingStore implements BillingStore {
  readonly devices = new Map<string, DeviceRow>();
  readonly consents: Array<{
    deviceId: string;
    version: number;
    acceptedAt: string;
    ip: string | null;
    userAgent: string | null;
    createdAt: string;
  }> = [];
  readonly cards = new Map<string, CardRow>();

  async deviceById(id: string): Promise<DeviceRow | null> {
    return this.devices.get(id) ?? null;
  }

  async deviceByTokenHash(tokenHash: string): Promise<DeviceRow | null> {
    for (const device of this.devices.values()) {
      if (device.tokenHash === tokenHash) return device;
    }
    return null;
  }

  async deviceByCustomerId(customerId: string): Promise<DeviceRow | null> {
    for (const device of this.devices.values()) {
      if (device.stripeCustomerId === customerId) return device;
    }
    return null;
  }

  async registerDevice(input: {
    id: string;
    tokenHash: string;
    platform: string | null;
    appVersion: string | null;
    now: string;
  }): Promise<DeviceRow> {
    const existing = this.devices.get(input.id);
    const row: DeviceRow = {
      id: input.id,
      tokenHash: input.tokenHash,
      // Kept across a re-registration, exactly as D1's upsert keeps it.
      stripeCustomerId: existing?.stripeCustomerId ?? null,
      platform: input.platform,
      appVersion: input.appVersion,
      createdAt: existing?.createdAt ?? input.now,
      updatedAt: input.now,
    };
    this.devices.set(input.id, row);
    return row;
  }

  async setCustomerId(
    deviceId: string,
    customerId: string,
    now: string,
  ): Promise<void> {
    const device = this.devices.get(deviceId);
    if (!device) return;
    this.devices.set(deviceId, {
      ...device,
      stripeCustomerId: customerId,
      updatedAt: now,
    });
  }

  async addConsent(input: {
    deviceId: string;
    version: number;
    acceptedAt: string;
    ip: string | null;
    userAgent: string | null;
    now: string;
  }): Promise<void> {
    this.consents.push({
      deviceId: input.deviceId,
      version: input.version,
      acceptedAt: input.acceptedAt,
      ip: input.ip,
      userAgent: input.userAgent,
      createdAt: input.now,
    });
  }

  async latestConsent(deviceId: string): Promise<ConsentRow | null> {
    for (let i = this.consents.length - 1; i >= 0; i--) {
      const row = this.consents[i];
      if (row.deviceId === deviceId) {
        return { version: row.version, acceptedAt: row.acceptedAt };
      }
    }
    return null;
  }

  async card(deviceId: string): Promise<CardRow | null> {
    return this.cards.get(deviceId) ?? null;
  }

  async cardByPaymentMethodId(paymentMethodId: string): Promise<CardRow | null> {
    for (const card of this.cards.values()) {
      if (card.paymentMethodId === paymentMethodId) return card;
    }
    return null;
  }

  async putCard(card: CardRow): Promise<void> {
    this.cards.set(card.deviceId, card);
  }

  async deleteCard(deviceId: string): Promise<void> {
    this.cards.delete(deviceId);
  }
}
