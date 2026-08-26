# Wake or Pay — 覚悟の目覚まし

> 「起きなかったら、知らないおじさんが儲かる。」

寝坊した分だけアラームコインが燃え、その額が「おじさん」の収益として表示される目覚まし。
Phase 0（端末内完結・サーバーなし・Android のみ）の実装。

仕様は [`docs/MVP_SPEC.md`](docs/MVP_SPEC.md) が正。

## 設計原則（変更不可）

1. 起こすための機能はすべて無料。枠数・回数・上位機能の制限は一切設けない。
2. 広告なし。スヌーズなし。課金誘導 UI なし。
3. コインとご褒美トークンは相互変換不可。UI にも変換経路を置かない。
4. 上限や残高に達しても**アラームは止まらない**。損失表示が止まるだけ。

## 技術スタック

| 領域 | 採用 |
|---|---|
| フレームワーク | Flutter（stable 3.47.1 / Dart 3.13.1）、Android のみ、minSdk 26 |
| 状態管理 | `flutter_riverpod` |
| 画面遷移 | `go_router` |
| アラーム | `alarm`（foreground service + full-screen intent） |
| 構造化永続化 | **`drift`**（SQLite） |
| 小さい設定 | `shared_preferences` |
| 権限 | `permission_handler` |

### なぜ drift を選んだか（hive / isar ではなく）

- **セッション履歴がクエリを要求する。** ウォレット画面の履歴、「鳴動中のセッションを新しい順に1件」といった復旧ロジックは、
  絞り込み・並び替え・件数制限がそのまま欲しい。drift なら型安全な SQL 一発で、hive のように全件ロードして Dart 側で
  ソートする必要がない。
- **テストが本物と同じコードパスを通る。** `NativeDatabase.memory()` により、リポジトリのテストが実機と同一の
  SQLite 実装に対して走る（`flutter test` のホスト側でそのまま動くことを確認済み）。モックではなく実データベース。
- **お金が絡むのでトランザクションが要る。** 「セッション確定 → コイン減算 → おじさんの累計加算」は不可分でなければ
  二重課金や取りこぼしになる。drift のトランザクションでまとめている。
- **スキーマ変更に耐える。** Phase 2 でカード人質・課金明細・証拠ログが増える。マイグレーションの手段が最初からある方が安い。
- isar は現在メンテナンス状況が不安定であること、hive は上記のクエリ／トランザクション要件に対して薄すぎることから見送った。

drift のコード生成物 `lib/data/database.g.dart` はリポジトリにコミットしている（CI でも生成不要）。
スキーマを変えたら:

```powershell
dart run build_runner build
```

## ビルドと実行

前提: Flutter stable / Android SDK / JDK 17 以降（Android Studio 同梱の jbr で可。
検証時の jbr は OpenJDK 25.0.2 で、ビルド・テストとも問題なく通っている）。

```powershell
$env:Path = "C:\Users\k023g\dev\flutter\bin;$env:Path"
flutter pub get
flutter analyze          # 警告ゼロであること
flutter test             # 全テストが通ること
flutter build apk --debug
flutter run              # 実機 / エミュレータ
```

APK は `build/app/outputs/flutter-apk/app-debug.apk` に出力される。

### 実機で確認すべきこと（**未実施**）

初回起動時に通知権限とアラーム権限（「アラームとリマインダー」）の許可を求める。
両方許可した上で、次の 5 項目を確認する。

1. **画面 OFF・ロック中に指定時刻に鳴る。** full-screen intent で鳴動画面がロック画面の上に出ること。
   `flutter run` した状態で 2 分後のアラームを設定し、画面を消して待つ。
2. **鳴動中にアプリをスワイプで殺しても音が続く。** 鳴っている最中にタスク一覧からアプリを消し、
   音が止まらないこと（foreground service）。通知をタップして鳴動画面に戻れること。
3. **「解除」以外では止まらない。** 通知をスワイプしても、戻るボタンでもホームボタンでも音が止まらず、
   起床確認をクリアしたときだけ止まること。通知に停止ボタンとスヌーズが出ていないこと。
4. **再起動後の復帰。** 鳴動中にアプリを殺して開き直すと鳴動画面に戻ること。
   端末の日時を 60 分以上進めてから開き直すと、失敗として自動確定されリザルトが出ること。
5. **損失が予定時刻から数えられていること。** 通知を無視して 3 分後にアプリを開き、
   すでに 3 分ぶん燃えていること（開いた瞬間から 0 ではない）。

補足：メーカーによってはバッテリー最適化を無効にしないと鳴らない（dontkillmyapp.com 参照）。

## 音源

`assets/audio/alarm.wav` はこのリポジトリのために合成した単純なビープ音（本リポジトリと同一ライセンス、
第三者の権利を含まない）。差し替える場合はライセンスをここに明記すること。

## 構成

```
lib/
  main.dart              起動、Riverpod コンテナ、AlarmService の起動
  app/                   router.dart, theme.dart, theme_controller.dart
  domain/                models/ と純粋ロジック
    loss_calculator.dart lossAt / judgeStatus / finalizeSession / recoverSession
    ojisan.dart          成長セリフ
    reward.dart          ご褒美トークン付与
    schedule.dart        nextFireTime
    wake_check.dart      長押し進捗・計算問題生成・入力文
    format.dart          曜日・時刻・覚悟の表示整形
  data/                  drift スキーマ、mappers、repositories、providers
  services/
    alarm_service.dart   alarm パッケージのラッパー（予約・鳴動・復帰）
    session_service.dart セッションの開始と確定（ウォレット／おじさんの更新）
    alarm_settings_builder.dart  純粋関数：Alarm → AlarmSettings、予約判断
  features/              alarms / ringing / result / wallet / settings
test/                    domain・data・services・features のテスト
```

## 実装状況

- [x] step 1 プロジェクト生成、依存追加、router と空画面、テーマ基盤
- [x] step 2 domain 層（モデル＋純粋ロジック）と単体テスト
- [x] step 3 永続化（repositories）
- [x] step 4 アラームサービスと権限まわり
- [x] step 5 Ringing / Result / 起床確認 3 種
- [x] step 6 Home / AlarmEdit / Wallet / Settings（テーマ交換）
- [x] step 7 README

**残っているのは実機確認だけ**（下記「実機で確認すべきこと」の 5 項目）。エミュレータ／実機が
接続された環境では未実行のため、鳴動そのものは一度も検証できていない。

### テストの構成

| ファイル | 内容 |
|---|---|
| `test/domain/` | 損失計算・成功失敗判定・復旧・成長セリフ・トークン・次回鳴動時刻・起床確認・表示整形 |
| `test/data/` | 5 リポジトリ（インメモリ DB ＋ モック preferences） |
| `test/services/` | `buildAlarmSettings` / `platformAlarmId` / `scheduleActionFor` / セッション確定と復旧 |
| `test/features/` | 鳴動〜解除〜リザルトの通し、AlarmEdit 保存 → Home 反映、ウォレット、テーマ交換 |
| `test/app/` | テーマ切替と永続化 |

## 既知の制約

- **実機・エミュレータでの動作確認が未実施。** アラームが実際に鳴ること、ロック画面に出ること、
  アプリを殺しても鳴り続けることは、いずれもコード上の設定と `alarm` パッケージのドキュメントに
  基づくものであり、観測されていない。
- **`alarm` パッケージが旧来の Kotlin Gradle Plugin を適用している。** ビルド時に Flutter が
  「将来のバージョンではビルドが失敗する」と警告する。現在の Flutter 3.47.1 ではビルド成功。
  パッケージ側の Built-in Kotlin 対応待ち。
- **メーカー独自の省電力設定。** Samsung / Xiaomi / OPPO などではバッテリー最適化を無効にしないと
  鳴らないことがある（dontkillmyapp.com）。アプリ内での案内は未実装。
- **`USE_FULL_SCREEN_INTENT` は Google Play の審査対象。** 目覚まし用途としての正当性説明が必要。
- 鳴動中の再スケジュールは行わない（`Alarm.set` が鳴動中のアラームを置き換えてしまうため）。
  起動時の `rescheduleAll` は `Alarm.isRinging` を見て鳴動中のものを飛ばし、繰り返しアラームの
  再武装は解除時（`AlarmService.stopRinging`）に行う。
- 通知アイコンは指定していないため、アプリアイコンが使われる（`alarm` パッケージのフォールバック）。
- ローカライズ基盤（arb）は未導入。文言は日本語のハードコード。

## 今後（Phase 1 以降、本 MVP のスコープ外）

カード人質（Stripe 等の Web 決済）、アプリ内課金、緊急連絡先への寝坊通知、SNS 共有、
キャラクター選択、顔認証・歩数による起床確認、iOS 対応。企画書 6 章を参照。
