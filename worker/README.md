# Discord 連携サーバー（Cloudflare Worker）

「チャンネルを連携（Discord で選ぶ）」のためだけの、**とても小さな中継**です。

## なぜ必要なのか

Discord に「このチャンネルに投稿していいよ」と言ってもらう（`webhook.incoming`）には、
**認可コードをアクセストークンに交換する**手順が要ります。そしてその交換には
**クライアントシークレット**が要る。シークレットを APK に埋めたら、それはもう
シークレットではありません（APK は誰でも解凍して中を読めます）。

なので、シークレットを持つ役だけをここに切り出しています。

- **ユーザーのデータは何も持ちません。** DB もセッションもログもありません。
  1 リクエストにつき 1 回 Discord に聞いて、答えを返して、忘れます。
- **アクセストークンもリフレッシュトークンもアプリに返しません。**
  返すのは Webhook の URL とサーバー名だけ。ユーザーの代わりに何かができる値は
  1 つもアプリに渡りません。
- 「Discord で連携」（プロフィールのユーザーID のほう）は**このサーバーを使いません**。
  あちらは暗黙フローで完結するので、サーバーを立てなくても動きます。

## エンドポイント

```
POST /discord/exchange
Content-Type: application/json

{ "code": "…", "redirect_uri": "wakeorpay://discord/callback", "code_verifier": "…（任意）" }
```

成功すると：

```json
{
  "webhook": {
    "id": "999",
    "url": "https://discord.com/api/webhooks/999/…",
    "channel_id": "222",
    "guild_id": "111",
    "name": "Wake or Pay"
  },
  "guild_name": "みんなのサーバー",
  "channel_name": null
}
```

- `guild_name` は `identify` の権限で `/users/@me/guilds` を引いて解決します。
  引けなければ `null` で、アプリは Webhook 名にフォールバックします。
- **`channel_name` は常に `null`。** チャンネル名を読むには Bot をサーバーに入れるか
  `guilds.members.read` が要り、ラベルを綺麗にするためだけに、ユーザーの前に
  もっと怖い同意画面を出すことになります。割に合いません。
- 失敗は `{ "error": "…" }` と HTTP ステータス。Discord の本文はそのままは返しません
  （失敗した交換の本文にはパラメータがそのまま echo されるため）。

## デプロイ手順（この 5 つだけ）

Node.js が入っている前提です。

```bash
npm i -g wrangler          # 1. wrangler を入れる
wrangler login             # 2. ブラウザが開くので Cloudflare にログイン
cd worker
wrangler secret put DISCORD_CLIENT_SECRET
                           # 3. 貼り付ける（下の「シークレットの取り方」）
wrangler deploy            # 4. デプロイ
```

4 の最後に URL が出ます。

```
Deployed wake-or-pay-discord triggers (1.23 sec)
  https://wake-or-pay-discord.<あなたのサブドメイン>.workers.dev
```

5. **その URL をアプリに貼る。**
   プロフィール（ヘッダーのアイコン）→ Discord の島 →「連携サーバーURL」に
   `https://wake-or-pay-discord.<あなたのサブドメイン>.workers.dev` を入れて閉じます。
   末尾の `/discord/exchange` は**付けません**（アプリが付けます）。

再ビルドは要りません。URL は端末に保存され、いつでも消したり差し替えたりできます。

### シークレットの取り方

1. https://discord.com/developers/applications で対象のアプリを開く
2. 左の「**OAuth2**」→「**Client Secret**」→「**Reset Secret**」
   （一度しか表示されません。閉じたらまた Reset するだけです）
3. その文字列を `wrangler secret put DISCORD_CLIENT_SECRET` に貼る

**`wrangler.toml` には絶対に書かないでください。** あそこに書いたシークレットは、
リポジトリのすべてのコピーに入ります。`wrangler secret put` で入れたものは
Cloudflare 側に暗号化されて置かれ、`wrangler deploy` してもファイルには残りません。

### リダイレクト URI

Discord Developer Portal →「OAuth2」→「Redirects」に

```
wakeorpay://discord/callback
```

を**1 文字違わず**登録してください。ここが違うと、同意画面が出る前に
「無効な OAuth2 リダイレクト URI」で止まります。

## 開発

```bash
npm install
npm test          # vitest。fetch をスタブして Discord には出ない
npx tsc --noEmit  # 型
npm run dev       # wrangler dev（ローカル。シークレットは .dev.vars に置く）
```

`.dev.vars`（**git に入れない**。`.gitignore` 済み）：

```
DISCORD_CLIENT_SECRET=…
```

## 守っていること

- **レート制限**は IP ごとに 60 秒で 10 回。Worker のモジュールスコープに置いた
  だけの、isolate が生きている間しか効かない**速度制限**です。分散した本物の
  リミッタには Durable Objects が要りますが、この用途にはやりすぎです。
- **Origin チェック**：ブラウザから来た（`Origin` ヘッダーが付いている）リクエストは、
  `ALLOWED_ORIGINS` に載っていなければ 403。ネイティブアプリは `Origin` を
  付けないので通ります。この Worker の値はシークレットそのもので、
  1 リクエストごとにそれを使うので、どこかの Web ページの交換窓口にはさせません。
- **CSRF の `state`** はアプリ側で作って検証します（`lib/domain/discord_oauth.dart`）。
  サーバーは状態を持たないので、ここで照合することはできません。
