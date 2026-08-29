# 課金 API 契約（Phase 1：端末登録・カード人質の登録／解除）

Worker（`worker/`、Cloudflare Workers + D1）とアプリの間の契約。両側の実装はこの文書に従う。
Phase 1 では **請求は行わない**。カードを Stripe に保存し、その状態を持つところまで。

## 方針（docs/ALARM_V2_SPEC.md の「課金誘導なし」との関係）

- 禁止のまま：機能・スヌーズ・コインを「買わせる」UI、広告、課金で有利になる仕組み。
- 許可：**寝坊の罰としての請求**。これはアプリの前提（Wake *or Pay*）そのもの。
  ユーザーが自分で「カードを人質にする」と同意した場合にだけ、燃えたコイン相当額を
  **月末に合算して 1 回**請求する（Phase 3）。
- UI 文言は「請求」「カード」「人質」「決済」を使い、「課金」「購入」「広告」は使わない
  （既存の文字列禁止テストを維持）。

## 秘密の置き場

| もの | 置き場 |
|---|---|
| Stripe 公開可能キー `pk_test_…` / `pk_live_…` | アプリのビルド時定数（公開情報） |
| Stripe シークレットキー `sk_…` | Worker のシークレット `STRIPE_SECRET_KEY`（`wrangler secret put`） |
| Stripe Webhook 署名シークレット `whsec_…` | Worker のシークレット `STRIPE_WEBHOOK_SECRET` |
| 端末トークン | アプリの secure store のみ。Worker は **SHA-256 ハッシュ**だけ保存 |
| カード番号 | どこにも置かない。Stripe の PaymentMethod に留まる。Worker は brand/last4/期限だけ |

## 端末の識別と認証

- アプリは初回起動時に `installId`（UUID v4）を生成し secure store に保存する。
- `POST /v1/devices/register` で `deviceToken` を受け取り secure store に保存する。
- 以後の `/v1/billing/*` は `Authorization: Bearer <deviceToken>` 必須。
  無効なら `401 {"error":"unauthorized"}`。
- 同じ `installId` で再登録されたら **新しいトークンを発行し、古いハッシュを置き換える**
  （端末側でトークンだけ失われたときの復旧路）。Stripe Customer は引き継ぐ。

## エンドポイント

すべて JSON。エラーは `{"error": "<snake_case_code>", "message"?: string}`。
既存の `/discord/*` と `/.well-known/*` は無変更。

### `POST /v1/devices/register`
Request: `{"installId": "<uuid>", "platform": "android", "appVersion": "1.0.0+96"}`
Response `200`: `{"deviceToken": "<opaque, 43+ chars>"}`
- `installId` が UUID でなければ `400 {"error":"bad_install_id"}`。
- レート制限：既存の IP ベース制限を流用。

### `POST /v1/billing/setup-intent`（要認証）
カード登録の開始。Stripe Customer がなければ作る（`metadata.install_id`）。
Request: `{"consent": {"version": 1, "acceptedAt": "<ISO8601>"}}`
Response `200`:
```json
{
  "customerId": "cus_…",
  "ephemeralKeySecret": "ek_test_…",
  "setupIntentClientSecret": "seti_…_secret_…",
  "publishableKey": "pk_test_…"
}
```
- Stripe 呼び出し：`POST /v1/customers`（初回のみ）、`POST /v1/ephemeral_keys`
  （`Stripe-Version: 2024-06-20` 以上のヘッダ必須）、`POST /v1/setup_intents`
  （`customer`, `usage=off_session`, `payment_method_types[]=card`）。
- `consent` は **必須**。欠けていれば `400 {"error":"bad_consent"}` で、Stripe は呼ばない
  （同意の記録なしにカードを預かる状態を作らない）。D1 の `consents` に保存
  （version, accepted_at, ip, user_agent）。
- `publishableKey` は Worker の `[vars] STRIPE_PUBLISHABLE_KEY` を返す（アプリの定数と
  一致しているかの検証用。アプリは自分の定数を優先してよい）。

### `POST /v1/billing/card/confirm`（要認証）
PaymentSheet 完了後にアプリが呼ぶ。SetupIntent を検証し、PaymentMethod を既定にする。
Request: `{"setupIntentId": "seti_…"}`
Response `200`: `{"card": {"brand": "visa", "last4": "4242", "expMonth": 12, "expYear": 2030}}`
- Stripe から `GET /v1/setup_intents/{id}` を取り、**まず** `customer` が当該端末の Customer で
  あることを確認（違えば `403 {"error":"wrong_customer"}` — 他人の SetupIntent の状態を
  漏らさないため、status より先に判定する）、次に `status == "succeeded"` を確認
  （違えば `409 {"error":"setup_not_succeeded"}`）。
- `POST /v1/customers/{cus}` で `invoice_settings[default_payment_method]` を設定。
- D1 `cards` に brand/last4/exp/payment_method_id を upsert（1 端末 1 カード）。
  以前のカードがあれば Stripe から `POST /v1/payment_methods/{old}/detach`。

### `GET /v1/billing/card`（要認証）
Response `200`: `{"card": {...} | null, "consent": {"version":1,"acceptedAt":"…"} | null}`

### `DELETE /v1/billing/card`（要認証）
カード人質の解除。PaymentMethod を detach し `cards` 行を削除。Consent は履歴として残す。
Response `200`: `{"card": null}`（未登録でも 200）。

### `POST /v1/stripe/webhook`
Stripe からの通知。`Stripe-Signature` を `STRIPE_WEBHOOK_SECRET` で検証（HMAC-SHA256、
`t=…,v1=…`、許容ずれ 5 分）。検証失敗は `400`。`STRIPE_WEBHOOK_SECRET` 未設定なら `500`
（200 を返すと Stripe が配達済みと見なして再送しなくなるため）。
Phase 1 で扱うイベント：
- `setup_intent.succeeded` → confirm と同じ処理（アプリが confirm を呼べなかった場合の保険）。
- `payment_method.detached` → 該当 `cards` 行を削除。
それ以外は `200` で無視。

## D1 スキーマ（`worker/migrations/0001_billing.sql`）

```sql
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
```

## アプリ側の画面（Phase 1）

- プロフィールに行「クレジットカードを人質にする」：未登録は「なし」、登録済みは
  「VISA •••• 4242」。タップで `CardHostageScreen`。
- `CardHostageScreen`：
  1. 説明（何が・いつ・いくらまで請求されるか、解除方法、月末合算、上限は各アラームの上限金額）
  2. 同意チェック（マンデート文言：「Wake or Pay が、寝坊で確定した金額を毎月末にこのカードへ
     請求することに同意します。金額は各アラームの上限金額を超えません。いつでも解除できます。」）
  3. 「カードを登録」→ `/v1/devices/register`（未登録なら）→ `/v1/billing/setup-intent`
     → `flutter_stripe` PaymentSheet（setup モード）→ `/v1/billing/card/confirm`
  4. 登録済み表示（brand/last4/期限）と「解除」→ `DELETE /v1/billing/card`
- Stripe 公開可能キーはアプリ起動時に `Stripe.publishableKey` へ設定。
- 通信は `BillingApi` インターフェース経由（テストでは Fake）。PaymentSheet 呼び出しも
  `CardSheet` インターフェース経由（テストでは Fake）。

## Phase 3 への布石（実装はしない）

- `charges` 台帳：`session_id` を UNIQUE にして二重請求を構造的に防ぐ。
- 月末バッチ：Cron Trigger で端末ごとに合算 → `PaymentIntent(off_session=true, confirm=true)`。
- 失敗（`requires_payment_method`）→ アプリへ「カードの再認証が必要」を通知。
