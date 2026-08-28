# Discord 連携サーバー（Cloudflare Worker）

Discord 連携のための、**とても小さな中継**です。**両方の連携がここを通ります**
（段階G から。「Discord で連携」も暗黙フローをやめました）。

## なぜ必要なのか

**理由は 2 つあります。**

**1. シークレット。** 認可コードをアクセストークンに交換する手順には
**クライアントシークレット**が要ります。シークレットを APK に埋めたら、それはもう
シークレットではありません（APK は誰でも解凍して中を読めます）。

**2. リダイレクト先。** Discord はこのアプリのカスタムスキーム
（`wakeorpay://discord/callback`）をリダイレクト URI として**受け付けません**。
認可画面の前に「Redirect URI … is not supported by client」で止まります。
なのでリダイレクト先はこの Worker の https URL で、ここが着地点になります。

- **ユーザーのデータは何も持ちません。** DB もセッションもログもありません。
  1 リクエストにつき 1〜2 回 Discord に聞いて、答えを返して、忘れます。
- **アクセストークンもリフレッシュトークンもアプリに返しません。**
  返すのは Webhook の URL とサーバー名、あるいはユーザーの公開 4 項目だけ。
  ユーザーの代わりに何かができる値は 1 つもアプリに渡りません。
- **認可コードをログに出しません。** コールバックのページは `no-store` で、
  コードはページ内の 2 本の URL にしか現れません。

## エンドポイント

### `POST /discord/exchange`

```
Content-Type: application/json

{ "code": "…",
  "redirect_uri": "https://wake-or-pay-discord.wakeorpay.workers.dev/discord/callback",
  "mode": "identify" | "webhook",     // 省略時は "webhook"
  "code_verifier": "…（任意）" }
```

`mode: "webhook"`（「チャンネルを連携」）の成功：

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

`mode: "identify"`（「Discord で連携」）の成功。Worker の中で `/users/@me` を
**1 回だけ**引いて、公開されている 4 項目だけを返します：

```json
{ "user": { "id": "1234…", "username": "hanako",
            "global_name": "花子", "avatar": "abcdef" } }
```

### `GET /discord/callback?code=…&state=…`（`?error=…` も）

Discord がブラウザを返してくる先。小さな HTML を 1 枚返します。
持ち越すのは `code` `state` `error` `error_description` の 4 つだけです。

**主役は大きなボタン 1 個**（「**Wake or Pay を開く**」）で、その `href` が

```
intent://discord/callback?code=…&state=…#Intent;scheme=wakeorpay;package=com.wakeorpay.wake_or_pay;S.browser_fallback_url=…;end
```

です。**ブラウザに着地してしまったあと、確実に効くのはユーザーのタップだけ**だからです
（段階H。理由は上位 README の「段階Hで直したこと」に書いてあります。Chromium は
リダイレクトの終着点として着いた App Link をアプリに渡さないし、ユーザー操作なしの
未知スキームへのスクリプト遷移をブロックします）。見出しは「認証できました。あと 1 タップです。」
——ページが「終わった」ように見えると、ユーザーはここでブラウザを閉じてしまいます。

自動の再挑戦も**残してありますが best effort** です。読み込み直後に `intent://` へ、
1.2 秒後に `/discord/callback/return` へ、**1 フローにつき 1 回だけ**
（`sessionStorage` に `state` で印を付ける）。アプリが前に出たあとは撃ちません。

### `GET /discord/callback/return?code=…&state=…`

**2 本目の App Link パス**。同じパラメータを運ぶだけで、返すのは同じページの
**自動遷移なし版**です。ここに来ているということは自動遷移が効かなかったということなので、
ここでまた自動遷移するとループになります。`intent://` の `browser_fallback_url` も
（着地ページ自身ではなく）ここを指しています。

**App Links の検証が効いていて、かつ遷移の形が条件を満たせば、これらのページは
そもそも表示されません**——Android が https の遷移を直接アプリに渡すためです。

### `GET /.well-known/assetlinks.json`

その App Links の証明。`wrangler.toml` の `ANDROID_CERT_SHA256` を載せて返します。
Content-Type は `application/json`、リダイレクトなし（Android がどちらも要求します）。

**署名に使うキーストアを変えたら、この値も同じコミットで差し替えること。**

```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore \
        -alias androiddebugkey -storepass android
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

5. **その URL を `kDiscordExchangeEndpoint` に書いてビルドし直す。**
   `lib/services/discord_exchange.dart` の `kDiscordExchangeEndpoint` に
   `https://wake-or-pay-discord.<あなたのサブドメイン>.workers.dev` を入れて、
   アプリをビルドし直します。末尾の `/discord/exchange` は**付けません**（アプリが付けます）。

   このリポジトリのビルドはすでにデプロイ済みの URL を指しています：

   ```dart
   const kDiscordExchangeEndpoint =
       'https://wake-or-pay-discord.wakeorpay.workers.dev';
   ```

   プロフィールに URL を貼る場所はもうありません（`kDiscordExchangeEndpoint` が唯一の
   設定箇所です）。自分の Worker を建てたら、必ずこの定数を自分の URL に書き換えて
   **ビルドし直してください**。他人の Worker を指したままのビルドは、その人の
   クライアントシークレットを自分のユーザーの認可に使うことになります。

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
https://wake-or-pay-discord.wakeorpay.workers.dev/discord/callback
```

を**1 文字違わず**登録してください（自分の Worker を建てたなら、そのホスト名に
読み替えて `/discord/callback` を付けたもの）。ここが違うと、同意画面が出る前に
`discord.com/oauth2/error?error=invalid_request` で止まります。

**`wakeorpay://discord/callback` は登録しても通りません。** Discord は
カスタムスキームのリダイレクトをこのアプリに許さず、
「Redirect URI 'wakeorpay://discord/callback' is not supported by client」で断ります。
これが段階G でこのエンドポイントを増やした理由そのものです。

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
