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

前提: Flutter stable / Android SDK / JDK 17（Android Studio 同梱の jbr で可）。

```powershell
$env:Path = "C:\Users\k023g\dev\flutter\bin;$env:Path"
flutter pub get
flutter analyze          # 警告ゼロであること
flutter test             # 全テストが通ること
flutter build apk --debug
flutter run              # 実機 / エミュレータ
```

APK は `build/app/outputs/flutter-apk/app-debug.apk` に出力される。

### 実機で確認すべきこと（step 5 以降で実施）

1. 画面 OFF・ロック中に指定時刻に鳴る（full-screen intent で鳴動画面が前面に出る）
2. 鳴動中にアプリをスワイプで殺しても音が続く（foreground service）
3. 起床確認をクリアすると止まる。それ以外の経路（通知スワイプ・通知ボタン・戻るボタン）では止まらない
4. 再起動後に鳴動中セッションへ復帰する／60分超なら失敗として自動確定される
5. 端末のバッテリー最適化を無効化しないと鳴らない機種がある（dontkillmyapp.com 参照）

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
  data/                  drift スキーマ、mappers、repositories、providers
  services/
    alarm_service.dart   alarm パッケージのラッパー（予約・鳴動・復帰）
    session_service.dart セッションの開始と確定（ウォレット／おじさんの更新）
    alarm_settings_builder.dart  純粋関数：Alarm → AlarmSettings
  features/              alarms / ringing / result / wallet / settings
test/                    domain・data・services のテスト
```

## 実装状況

- [x] step 1 プロジェクト生成、依存追加、router と空画面、テーマ基盤
- [x] step 2 domain 層（モデル＋純粋ロジック）と単体テスト
- [x] step 3 永続化（repositories）
- [x] step 4 アラームサービスと権限まわり（**実機確認は未実施**）

### TODO（step 5〜7）

**step 5 — Ringing / Result / 起床確認**

- [ ] Ringing 画面：時刻、毎秒再描画の損失カウンタ（値は分単位）、おじさん、起床確認 UI
- [ ] 起床確認 3 種：longPress（5秒、離したらリセット）／ math（2桁＋2桁を3問連続）／ typing（12文字前後の日本語文を完全一致、コピー不可）
- [ ] 解除で `SessionService.dismiss` → `AlarmService.stopRinging` → Result へ
- [ ] Result 画面：成功／失敗、損失、獲得トークン、`ojisanLine(totalOversleeps)`
- [ ] ウィジェットテスト：Ringing の longPress 解除

**step 6 — Wallet / Settings / テーマ交換**

- [ ] Home：アラーム一覧（時刻・曜日・覚悟の rate/cap・ON/OFF）、上部にコイン／トークン残高、＋で追加
- [ ] AlarmEdit：時刻ピッカー、曜日、起床確認種類、覚悟トグル → rate（1/10/50/100/500 とカスタム）と cap。`cap > coins` で警告（保存は可能）
- [ ] Wallet：残高、開発用チャージ（+1,000コイン）、履歴（日時・結果・損失）
- [ ] Settings：テーマ交換（100 トークン）と `unlockedThemeIds` によるロック表示
- [ ] ウィジェットテスト：AlarmEdit の保存 → Home に反映

**step 7 — 仕上げ**

- [ ] 実機確認（上記5項目）と結果の記載
- [ ] 既知の制約の追記

### 既知の未解決点

- `judgeStatus` は仕様どおり `loss == 0` を成功としているため、**残高 0 で寝坊しても「起床成功」になる**。
  仕様 3 章の明文に従っているが、体験としては要検討。
- 復旧の安全弁は覚悟なしのアラームでも `failed` として確定する（仕様 3 章の明文どおり）。累計寝坊回数が増える。
- 鳴動中の再スケジュールは行わない（`Alarm.set` が鳴動中のアラームを置き換えてしまうため）。
  繰り返しアラームの再武装は解除時（`AlarmService.stopRinging`）と起動時（`rescheduleAll`）に行う。
