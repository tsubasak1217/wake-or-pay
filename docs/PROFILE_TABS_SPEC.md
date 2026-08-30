# プロフィール画面とタブ構成の仕様（2026-08-30 共有版）

スケッチ：`docs/design/profile_spec_2026-08-30.png`、`docs/design/tabs_spec_2026-08-30.png`、
`docs/design/profile_edit_spec_2026-08-30.png`（プロフィール編集画面）、
`docs/design/activity_spec_2026-08-30.png`（アクティビティ タブ）。
この文書は**仕様の固定**であり、実装状況は末尾の「現状との差分」を参照。

## 1. プロフィール画面（上からのオーバーレイ）

上から順に。**1〜4（頭）はシートの上端に固定**され、スクロールしない。5・6 だけが
その下でスクロールする（`TopSheetOverlay` の `header:` スロット。オプション画面は
`header` を渡さないので従来どおり）。下フリックでの退場は、グラブバーと頭
——スクロールしない場所——で従来どおり効く。

1. **アイコン**（円）と、その外側の**アイコンフレーム**（コレクション品。装飾的な縁）
2. **称号**：アイコン直下に小さく。`AAA + 接続詞 + BBB` の形式で、コレクションの
   語を組み合わせて作る（例：「寝坊の常習犯」）。
3. **ネームプレート**：名前を載せた板（コレクション品）。右横に **編集ボタン（鉛筆）**。
   押すと**プロフィール編集画面**へ遷移し、アイコン／フレーム／プレート／背景／称号などの
   コレクションを**プレビューしながら装備**できる。
4. **経験値ゲージ**：ネームプレートの直下。**ゲージの内部にランク**（Lv 表示）を描く。
   - **背景**（コレクション品）：1〜4 の**頭全体の背後**に敷く角丸の面。単色または
     2 色グラデーションで、任意で模様（`none` / `dots` / `stripes`）を持つ。既定は
     「なし」＝完全に透明で、背景が無かった頃の頭と 1 ドットも変わらない。
5. **これまでの歩み**（島）：
   - 開始日
   - ログイン日数
   - 累計ペナルティ額
   - 最大ペナルティ額
   - 起床成功率
   - 累計寝坊回数
   - 累計寝坊時間
   - 最大寝坊時間
   - 所持コレクション数 n / 総数
   - （その他、後で増やす）
6. **連携情報**（島）：外部とのつながりを一箇所に。**3 行だけ**で、各行は `SettingRow`
   （左に `leading` アイコン、ラベル、右に **未連携／連携済み** と `>`）。
   **副題・説明文・インラインのボタンは置かない**——島は「何と繋がっているか」の索引で、
   連携・解除・詳細はすべてタップした先のサブ画面で行う。カード番号（`****1234`）や
   メールアドレスも状態ではなく詳細なので出さない。
   - **Discord**（`profileDiscordRow`、`DiscordIcon`）→ `DiscordLinkScreen`
     （`lib/features/profile/discord_link_screen.dart`、AppBar「Discord」）。
     「Discord で連携」／連携済み＋「連携を解除」／`DiscordFlowStatusView` は
     `DiscordLinkRow` ごとこの画面の中身になった。
   - **クレジットカード**（`profileCardHostageRow`、`Icons.credit_card`）→ `CardHostageScreen`
   - **メール**（`profileMailRow`、`Icons.mail_outline`）→ `MailSettingsScreen`

オプション（アプリの更新、危険な設定など）は**プロフィールではなくオプション画面**
（ヘッダー右端のボタン → 同じ要領で上から表示）に置く。

### 1-b. プロフィール編集画面（`docs/design/profile_edit_spec_2026-08-30.png`）

上から 3 段。**上 2 段は固定**、いちばん下だけがその中でスクロールする。

1. **プレビュー**（固定）：プロフィールの頭そのもの（背景＋アイコン＋フレーム／称号／
   ネームプレート／ランク内蔵ゲージ）。鉛筆は無い——ここが鉛筆の行き先だから。
2. **カテゴリのチップ**（2 段の `Wrap`）：「アイコン」「フレーム」「プレート」「背景」／
   「称号A」「称号B」「称号C」。キーは `editCategory-icon` / `-frame` / `-plate` /
   `-background` / `-titleA` / `-titleB` / `-titleC`。
3. **パネル**（`editPanel`、角丸。**この中でスクロール**）：選ばれたカテゴリの品を並べる。
   コレクション品はスウォッチ（背景は塗りの小さな見本）、称号は語のチップ。選択中は
   枠が強調され、**未所持は灰色で選べない**（従来どおりの規則）。

**名前**にはもう単独の入力欄が無い（スケッチにも無い）。**プレビューのネームプレートを
タップ**（`editNameplate`）すると「名前を変更」の `AlertDialog`（`profileEditName`）が
開き、OK が下書きに書く。保存は従来どおり**画面を閉じたときに一括**。

## 2. タブ構成（下部 4 タブ）

| タブ | 中身（想定） |
|---|---|
| **アラーム** | 現在のホーム（アラーム一覧・追加・編集） |
| **アクティビティ** | 今月の寝坊ペナルティ／起床時間の遷移／寝坊連絡・共有履歴／寝言の録音（下記 2-b） |
| **庭** | 現在の庭 |
| **ショップ** | **純粋な購入画面**（コインの入手など。機能を売る画面にはしない） |

### 2-b. アクティビティ タブ（`docs/design/activity_spec_2026-08-30.png`）

上から 4 枚の島。いずれも読むだけ——録音の削除以外、ここでの操作が明日の請求を
変えることはない。

1. **今月の寝坊ペナルティ**（`activityMonthCard`）
   - 小さい 1 行：「寝坊回数 N回　総寝坊時間 Xm」。当月（暦月）の **失敗** セッション数と、
     その `dismissedAt − firedAt` の合計（表記は `journeyDurationLabel`）。
   - 大きい数字 2 段：**カード人質の請求予定額**「N円」と **コイン人質の減少分**「Nコイン」。
     0 でも「0円」「0コイン」と出す。どちらの財布から出たかは**台帳（`pending_charges`）が
     決める**——カード人質でもカード未登録なら実際にはコインが減っているので、
     人質の設定ではなく charge 行の有無で振り分ける。
   - 右下のリンク「ペナルティ履歴 >」（`activityPenaltyHistoryLink`）→ `PenaltyHistoryScreen`。
   - 島の外・下に小さく脚注「※総額50円未満の場合は請求されません」（`docs/BILLING_API.md`
     の最低請求額 50 円）。
2. **起床時間の遷移(30日間)**（`activityWakeChart`）
   - 直近 30 日、1 日 1 点の折れ線。その日に**最初に解除されたセッションの `dismissedAt`**
     の時刻（成功・失敗を問わない）。記録の無い日は点を打たず、**線は前後を繋ぐ**
     （切ると「起きなかった」に見えるが、実際は「記録が無い」だけなので）。
   - 平均線（`平均 7:12`）を薄い色で横に引く。
   - 自前の `CustomPainter`（`wake_time_painter.dart`）。チャート依存は入れない。
   - 右下「もっと見る >」（`activityWakeMoreLink`）→ `WakeTimeHistoryScreen`：
     **全期間**の同じグラフを `InteractiveViewer`（横スクロール＋ピンチ、`minScale 1` /
     `maxScale 6`）に入れたもの。
3. **寝坊連絡・共有履歴**（`activityContactLog`）
   - 直近 **5 件**のみ。1 件も無ければ「まだ記録はありません」。
   - 右下「もっと見る >」（`activityContactMoreLink`）→ `ContactLogArchiveScreen`：
     データのある年だけを新しい順に並べ、各年に 3×4 の月の島「1月」…「12月」
     （`archiveMonth-YYYY-MM`）。**データの無い月は灰色で非アクティブ**、
     **今月より先の月とデータの無い年は表示しない**。月を選ぶと、グリッドの下に
     その月の一覧が出る（島は選択中として強調）。
4. **寝言の録音**（`activityRecordings`）：従来どおり。

旧「起床・寝坊の記録」ストリップと、タブ上の旧「ペナルティ履歴」一覧・棒グラフは
**廃止**（後者は `PenaltyHistoryScreen` に移った）。

`PenaltyHistoryScreen`（`activityPenaltyHistoryLink` の行き先）は、全期間の日別
ペナルティ額を**コイン／カードの 2 色の積み上げ棒**（凡例つき）で `InteractiveViewer`
に入れ、その下に**選択中の日のログ**（時刻・成功／寝坊・失った額と単位・スヌーズ回数）を
出す。棒をタップすると選択が移る（`GestureDetector` は `InteractiveViewer` の**中**に
置くので、座標はグラフ自身のもので、行列を手で逆変換しない）。既定は**最後に何か
失った日**。

## 3. 現状との差分（2026-08-30 時点）

### 実装済み（§1 プロフィール画面は一通り完了）

- ヘッダーのアバターからプロフィールが上から開く。
- プロフィール本体は上から **アイコン＋アイコンフレーム／称号／ネームプレート＋鉛筆／
  ランク内蔵の経験値ゲージ／「これまでの歩み」島／「連携情報」島** の順（`profile_overlay.dart`、
  頭の 4 つは `profile_head.dart`）。頭は `TopSheetOverlay(header:)` に渡して**固定**し、
  スクロールするのは 2 つの島だけ。
- **背景**：`ProfileCatalog.backgrounds`（「なし」＝透明・夜空・朝焼け・深緑・霧）と
  `ProfileBackground {id, name, colors, pattern}`。`Profile.backgroundId`（既定 `'none'`）と
  `ownedBackgroundIds` を `profile.backgroundId` / `profile.ownedBackgroundIds` に保存
  （キーが無い旧インストールは「なし」＋全所持に落ちる）。塗りとグラデーションは
  `ProfileHead` が、模様は `BackgroundPatternPainter` が描く。所持コレクション数にも入る。
- **称号**：`lib/domain/title_catalog.dart`（前半 8・接続詞 3・後半 8 語）と `composeTitle`。
  `Profile.titlePrefixId / titleConnectorId / titleSuffixId` と `ownedTitleWordIds` を
  shared_preferences に保存（キーが無い旧インストールは「寝坊の常習犯」＋全所持に落ちる）。
- **プロフィール編集画面**（`profile_edit_screen.dart`、鉛筆から遷移）：§1-b のとおり
  **固定プレビュー／カテゴリのチップ 2 段／中でスクロールするパネル** の 3 段。縦一列に
  ピッカーを並べていた旧レイアウトは廃止した（品を選ぶたびに結果が画面外へ流れていた）。
  所持していない品は選べない。閉じたときに一括保存。
- 「あなたの名前」の単独画面は廃止。名前はプレビューのネームプレートをタップして開く
  「名前を変更」ダイアログで変える（`editNameplate` → `profileEditName`）。
- **これまでの歩み**：`lib/domain/journey_stats.dart`（純粋関数）で
  開始日／ログイン日数／累計・最大ペナルティ額／起床成功率／累計寝坊回数／累計・最大寝坊時間／
  所持コレクション数 n/総数 を算出。履歴は上限なしの `allSessionsProvider`
  （`AlarmSessionRepository.watchAll`）から読む。
- **開始日とログイン日数**：`lib/data/repositories/usage_repository.dart` と
  `UsageTracker`（`usageProvider`）。アプリ起動ごとに 1 回だけ記録し、同じ暦日の再起動は
  1 日と数える。記録は `main()` ではなく（この回の作業では触れられない）、全タブが被る
  ヘッダーが `usageProvider` を watch した時点で走る。
- 「アプリの更新」行：オプション画面へ移動済み。
- `frameId` は**アイコン**のフレームに一本化した（ヘッダーのネームプレートの枠線は廃止）。

### 実装済み（§2 のタブも完了）

- 下タブは **アラーム／アクティビティ／庭／ショップ** の 4 つ（`shell_scaffold.dart`、
  ルートは `/`・`/activity`・`/garden`・`/shop`）。ウォレット タブは廃止し、
  `AppRoute.wallet` は `/shop` の別名として残した（ヘッダーの「＋」の行き先）。
- **アクティビティ**（`features/activity/activity_screen.dart`）は §2-b のスケッチ
  どおりの 4 つの島：「今月の寝坊ペナルティ」「起床時間の遷移(30日間)」
  「寝坊連絡・共有履歴」「寝言の録音」。計算はすべて `domain/activity_stats.dart` の
  純関数（`monthlyPenalty` / `wakeTimes` / `averageTimeOfDay` / `penaltyByDay` /
  `sessionsOn` / `monthsWithEvents` / `eventsInMonth`）で、単体テスト済み。
  描画は自前の `CustomPainter` 2 枚（`wake_time_painter.dart` の折れ線＋平均線、
  `day_bars_painter.dart` の `PenaltyBarsPainter` の積み上げ棒）で、
  チャート依存は入れていない。
  行き先は `penalty_history_screen.dart` / `wake_time_history_screen.dart` /
  `contact_log_archive_screen.dart`。連絡ログの 1 行は `contact_event_tile.dart` に
  切り出して、タブとアーカイブで同じ見た目にしてある。
  アーカイブは上限なしの `allContactEventsProvider`
  （`ContactEventRepository.watchAll`）を読む——タブの島だけが `contactEventsProvider`
  （直近 100 件）のまま。
- **ショップ**（`features/shop/shop_screen.dart`）は「純粋な購入画面」：残高と
  「コインを手に入れる」（開発用チャージ）と「コインの入手方法は準備中です。」だけ。
  履歴・連絡ログ・設定への行はここから外した。
- 設定（テーマ）への入口は**オプション**の「設定・テーマ」の行に移った。

### 未実装

- コレクションを**入手する仕組み**：所持集合を見て描いてはいるが、いまも既定は「全部所持」。
- ショップの**実際のコイン入手**（Phase 2 のプリペイド）。いまは開発用チャージだけ。
