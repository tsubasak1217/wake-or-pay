/// The ojisan's line after a failed wake-up, by lifetime oversleep count.
///
/// Pure. [totalOversleeps] includes the failure being reported, so the first
/// failure calls this with 1.
String ojisanLine(int totalOversleeps) {
  if (totalOversleeps >= 20) return 'おかげさまで会社を辞めました。';
  if (totalOversleeps >= 10) return 'おかげさまで引っ越しました。';
  if (totalOversleeps >= 3) return 'おかげさまで新しい靴買えました。';
  return 'ありがとうございます。あなたのおかげで今日も昼飯が食えます。';
}

/// What he says when he gets nothing.
const ojisanSuccessLine = 'チッ……';

/// What he says while the coins are still burning.
const ojisanRingingLine = 'ありがとうございます。';
