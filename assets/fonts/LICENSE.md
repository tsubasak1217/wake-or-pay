# assets/fonts ライセンス表記

本ディレクトリ (`assets/fonts/`) に同梱されているフォントファイルは、
**M PLUS Rounded 1c**（作者: Coji Morishita / M+ FONTS PROJECT）です。
本リポジトリが著作権を持つ原著作物ではなく、第三者の著作物を再配布しています。

## ライセンス

**SIL Open Font License, Version 1.1 (SIL OFL 1.1)**

ライセンス全文は、フォント本体と同じディレクトリの [`OFL.txt`](OFL.txt) に
同梱してあります（配布元のものをそのままコピーしたもので、改変していません）。
SIL OFL 1.1 はフォントファイルの再配布・組み込みを許可しており、
ライセンス全文を同梱することが条件のひとつです。

要点（拘束力を持つのは `OFL.txt` の原文です）:

- フォント単体の販売は不可。アプリケーションへの同梱・再配布は可。
- 改変・派生は可。ただし予約フォント名 (Reserved Font Name) は使えない。
- 上記のライセンス全文を、同梱・派生物のいずれにも添付すること。

## ファイル一覧

| ファイル名 | ウェイト | 用途 |
| --- | --- | --- |
| `MPLUSRounded1c-Regular.ttf` | 400 | 本文。アプリ全体の既定 |
| `MPLUSRounded1c-Medium.ttf` | 500 | 見出し・強調 |
| `MPLUSRounded1c-Bold.ttf` | 700 | 覚悟の金額など、強く読ませたいところ |
| `OFL.txt` | — | ライセンス全文（上記） |

`pubspec.yaml` では `MPLUSRounded1c` というファミリ名で、上記3ウェイトを
`weight: 400 / 500 / 700` として宣言しています。アプリ側は
`lib/app/theme.dart` の `appFontFamily` から全テーマに適用します。

## 備考

- 同梱しているのは上記3ウェイトのみです。配布元には Thin / Light /
  ExtraBold / Black もありますが、アプリが使わないウェイトを APK に入れると
  1ウェイトあたり約 3.4MB 増えるだけなので、入れていません。
- ファミリ名 `MPLUSRounded1c` は予約フォント名の改変には当たりません
  （フォント自体を改変しておらず、Flutter 側の参照名にすぎないため）。
