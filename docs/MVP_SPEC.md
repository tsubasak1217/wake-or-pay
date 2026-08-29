# Wake or Pay — MVP 実装仕様（Phase 0：端末内完結版）

企画書：`C:\Users\k023g\OneDrive\デスクトップ\Wake or Pay_企画書.md`（本仕様と矛盾する場合は本仕様が優先。企画書の思想＝設計原則は常に優先）

## 0. スコープ

**作るもの**（すべて端末内で完結。サーバーなし）

1. 通常の目覚まし（複数アラーム、曜日繰り返し、大音量、端末スリープ中でも確実に鳴る）
2. 起床確認（長押し／計算／文字入力）
3. 覚悟モード：人質A「アラームコイン」のみ。1分ごとにコインが燃える
4. おじさん演出（1種類）：鳴動中の収益表示、成功／失敗リザルト、累計寝坊回数による成長セリフ
5. ご褒美トークン：起床成功で獲得。テーマ（配色）3種の交換
6. ウォレット画面：コイン残高・トークン残高。**課金は未実装**なので「開発用チャージ（+1,000コイン）」ボタンで代用

**作らないもの**（後続フェーズ）：カード人質、アプリ内課金、寝坊通知、SNS共有、広告、顔認証・歩数、キャラ選択、iOS対応

> カード人質は後続フェーズで着手済み。契約は `docs/BILLING_API.md`。**罰としての請求（カード人質、月末合算）は許可、機能を売る課金は引き続き禁止**。

## 1. 技術スタック

- Flutter（stable）/ Dart、対象 Android（minSdk 26 以上、targetSdk は Flutter デフォルト）
- 状態管理：`flutter_riverpod`
- 画面遷移：`go_router`
- アラーム：pub.dev の `alarm` パッケージ（Android で foreground service を用い、端末スリープ中も鳴動する）。full-screen intent で鳴動画面を前面に出す。必要な権限（`SCHEDULE_EXACT_ALARM` / `USE_FULL_SCREEN_INTENT` / `POST_NOTIFICATIONS` 等）は Manifest とランタイム要求の両方を実装する
- 永続化：`shared_preferences`（小さい設定）＋ `drift` または `hive`（アラーム・セッション・ウォレット）。実装エージェントが選んでよいが、選定理由を README に書く
- 音源：リポジトリ同梱のフリー音源1つ（ライセンス明記）
- UI 文言：日本語。ローカライズ基盤（`flutter_localizations` + arb）は入れてよいが必須ではない

## 2. ドメインモデル

```
Alarm
  id: String
  hour, minute: int
  repeatDays: Set<int>      // 1=月 … 7=日。空なら一回限り
  enabled: bool
  wakeCheck: WakeCheckType  // longPress | math | typing
  graceMinutes: int         // 起床猶予。1〜5、既定 1
  kakugo: Kakugo?           // null = 覚悟モードなし（通常目覚まし）

Kakugo（覚悟）
  hostage: HostageType      // MVPでは coin のみ
  ratePerMinute: int        // 1分あたり燃えるコイン
  cap: int                  // このアラーム1回での最大損失

AlarmSession（1回の鳴動）
  id, alarmId
  firedAt: DateTime
  dismissedAt: DateTime?
  status: ringing | success | failed
  loss: int                 // 確定した損失コイン
  kakugoSnapshot: Kakugo?   // 鳴動時点の設定を固定
  graceMinutes: int         // 鳴動時点の起床猶予を固定（通常アラームも持つ）

Wallet
  coins: int
  tokens: int

OjisanState
  totalOversleeps: int      // status == failed の回数
  totalEarned: int          // 累計で燃えたコイン

Settings
  themeId: String
  unlockedThemeIds: Set<String>
```

## 3. 損失計算（最重要ロジック。純粋関数として実装し、単体テスト必須）

### 3.1 起床猶予（graceMinutes）

鳴り始めてから何分までを「起きられた」とみなすか。アラームごとに 1〜5 分から選び、既定は 1 分。
`Alarm.graceMinutes` に持ち、鳴動開始時に `AlarmSession.graceMinutes` へ固定する
（`kakugoSnapshot` の中ではなく**セッション自身**に持たせる。覚悟モードなしのアラームにも猶予はあるため）。
1〜5 の範囲外の値は、読み出し・計算のたびに 1〜5 へ丸める（DB を手で書き換えられても窓は広がらない）。

```
lossAt(now, session):
  if kakugoSnapshot == null → 0
  elapsedMinutes  = floor((now - firedAt) / 1min)    // 7:00:59 は 0分、7:01:00 は 1分
  billableMinutes = max(0, elapsedMinutes - graceMinutes + 1)
  raw = billableMinutes * ratePerMinute
  return min(raw, cap, coinsAtFire)
```

- **成功／失敗の判定**：`elapsedMinutes < graceMinutes` なら success、それ以外は failed
- 猶予 1 分は従来のルールとまったく同じ（59秒でクリア → 成功・損失0、7:01 → 100、7:07 → 700）
- 猶予 5 分の例：7:04:59 → 成功・0／7:05:00 → 失敗・100／7:06:00 → 失敗・200
- **60 分の安全弁は猶予に関係なく 60 分のまま**
- 鳴動画面は猶予が残っている間「猶予 あと 3:42」を表示し、切れた瞬間から損失カウンタに切り替わる

### 3.2 確定と判定

- `coinsAtFire`：鳴動時点の残高。残高より多く燃やさない
- 起床確認クリア時刻を `dismissedAt` として `loss = lossAt(dismissedAt)` を確定し、`Wallet.coins -= loss`、`OjisanState.totalEarned += loss`
- **成功／失敗の判定**：損失額ではなく**経過時間**で判定する（上記 3.1）。残高0・上限0・rate 0 で損失が出なくても、寝坊は寝坊
- **鳴動開始時刻 `firedAt` はアラームの予定時刻**（プラットフォームから渡される `dateTime`）を使う。アプリを開いた時刻ではない。通知を無視して後からアプリを開いても、損失は予定時刻から数える
- **おじさんの累計寝坊回数 `totalOversleeps` は、覚悟モードのセッション（`kakugoSnapshot != null`）が failed になった時だけ増える**。通常アラームの失敗は履歴には残るがおじさんは儲からないので数えない。`totalEarned` は loss の合計
- ご褒美トークンは success の時だけ付与
- **上限や残高に達してもアラームは止めない**。損失表示が止まるだけ
- **起動時の再スケジュールは、鳴動中のアラームを上書きしない**（プラットフォーム側で鳴動中かを確認してスキップする）
- **アプリが殺された／再起動した場合の復旧**：`status == ringing` のセッションが残っていれば、起動時に鳴動画面へ復帰する。ただし `firedAt` から 60 分以上経過していれば、`loss = lossAt(firedAt + 60min)` で failed として自動確定し、リザルトを表示する（無限に鳴り続けない安全弁）

## 4. 起床確認

| 種類 | 内容 |
|---|---|
| longPress | ボタンを 5 秒間押し続ける。離したらリセット |
| math | 2桁＋2桁の足し算を3問連続正解。間違えたら問題を変えて継続 |
| typing | 表示された 12 文字前後の日本語文（例「今日も絶対に起きる」）を完全一致で入力。コピー不可 |

鳴動画面では戻るボタン・ホームボタンでアプリを閉じても音は止めない（foreground service 側で鳴らし続ける）。「解除」以外の経路で止める手段を UI に置かない。

## 5. おじさん演出

- 鳴動画面：損失がリアルタイム更新（毎秒再描画、値は分単位）
  ```
  💸 あなた：−150
  👨 おじさん：+150
  「ありがとうございます。」
  ```
- 成功リザルト：「起床成功 / 消費：0 / 守った金額：{cap}」＋ 👨「チッ……」
- 失敗リザルト：「起床失敗 / 消費：{loss}」＋ 成長セリフ
- 成長セリフ（`totalOversleeps` で判定、純粋関数＋単体テスト）：

| 累計寝坊 | セリフ |
|---|---|
| 1〜2 | 「ありがとうございます。あなたのおかげで今日も昼飯が食えます。」 |
| 3〜9 | 「おかげさまで新しい靴買えました。」 |
| 10〜19 | 「おかげさまで引っ越しました。」 |
| 20〜 | 「おかげさまで会社を辞めました。」 |

- 画像は MVP では絵文字 👨 または同梱の簡易イラスト（プレースホルダー可）

## 6. ご褒美トークン

- 起床成功で付与：基本 10。覚悟モードありなら `+ ratePerMinute / 10`（切り捨て、最大 +50）。純粋関数＋テスト
- テーマ 3 種（デフォルト無料、残り 2 種はそれぞれ 100 トークン）。テーマ変更はアプリ全体の配色に即時反映
- トークンとコインは相互変換不可。UI にも変換経路を置かない

## 7. 画面

1. **Home**：アラーム一覧（時刻、曜日、覚悟の有無と rate/cap、ON/OFF）。右下＋で追加。上部にコイン／トークン残高
2. **AlarmEdit**：時刻ピッカー（iOS 風のホイール、24時間表記、画面内にインライン表示。モーダルダイアログは使わない）、曜日、起床確認種類、起床猶予（1〜5分）、覚悟トグル → rate（プリセット 1/10/50/100/500 とカスタム）と cap。保存時、`cap > coins` なら警告（保存は可能）
3. **Ringing**（全画面・スリープ解除・ロック画面上に表示）：時刻、損失カウンタ、おじさん、起床確認 UI
4. **Result**：成功／失敗、損失、獲得トークン、おじさんセリフ、「閉じる」
5. **Wallet**：残高、開発用チャージボタン、履歴（セッション一覧：日時・結果・損失）
6. **Settings / Theme**：テーマ選択と交換

## 8. 非機能・品質

- `flutter analyze` 警告ゼロ
- 単体テスト：損失計算、成功／失敗判定（猶予 1 分と 5 分の境界＝59秒/60秒、4:59/5:00 を含む）、成長セリフ、トークン付与、復旧ロジック（60分超の自動確定）、スキーマ移行
- ウィジェットテスト：AlarmEdit の保存 → Home に反映、Ringing の longPress 解除
- 実機／エミュレータで確認する項目（README に手順を書く）：画面OFF・ロック中に指定時刻に鳴る／鳴動中にアプリをスワイプで殺しても音が続く／解除で止まる／再起動後の復帰
- 設計原則の遵守：無料機能への制限、広告、スヌーズ、課金誘導の UI を**作らない**（罰としての請求＝カード人質は例外で、`docs/BILLING_API.md` に従う。売るための UI ではない）

## 9. リポジトリ構成（目安）

```
wake-or-pay/
  lib/
    main.dart
    app/            router, theme
    domain/         models, loss_calculator.dart, ojisan.dart, reward.dart（純粋ロジック）
    data/           repositories, local storage
    features/
      alarms/  ringing/  result/  wallet/  settings/
    services/       alarm_service.dart（alarm パッケージのラッパー）
  test/
  docs/
  README.md
```

## 10. 実装順序（各ステップで build と test が通る状態を保つ）

1. プロジェクト生成、依存追加、router と空画面、テーマ基盤
2. domain 層（モデル＋純粋ロジック）と単体テスト
3. 永続化（repositories）
4. アラームサービス（鳴動 → Ringing 画面起動）と権限まわり。ここで実機確認
5. Ringing／Result／起床確認
6. Wallet／Settings／テーマ交換
7. README（セットアップ、実機確認手順、既知の制約）
