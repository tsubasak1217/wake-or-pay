-- 課金（Phase 1）のスキーマ。docs/BILLING_API.md の「D1 スキーマ」そのもの。
--
--   wrangler d1 migrations apply wake-or-pay-billing --remote
--
-- カード番号はここに **入りません**。入るのは brand / last4 / 期限と
-- PaymentMethod の id だけで、番号は Stripe に留まります。
-- 端末トークンも入りません——入るのはその SHA-256 だけです。

CREATE TABLE devices (
  id TEXT PRIMARY KEY,               -- installId (uuid)
  token_hash TEXT NOT NULL UNIQUE,   -- sha256(deviceToken) hex
  stripe_customer_id TEXT UNIQUE,
  platform TEXT, app_version TEXT,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE consents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL REFERENCES devices(id),
  version INTEGER NOT NULL, accepted_at TEXT NOT NULL,
  ip TEXT, user_agent TEXT, created_at TEXT NOT NULL
);
CREATE TABLE cards (
  device_id TEXT PRIMARY KEY REFERENCES devices(id),
  payment_method_id TEXT NOT NULL,
  brand TEXT NOT NULL, last4 TEXT NOT NULL,
  exp_month INTEGER NOT NULL, exp_year INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

-- payment_method.detached の webhook は PaymentMethod の id しか持たないので、
-- そこから行を引ける必要があります。
CREATE UNIQUE INDEX cards_payment_method_id ON cards (payment_method_id);
CREATE INDEX consents_device_id ON consents (device_id, id DESC);
