import 'package:flutter/foundation.dart';

/// 称号 — one word of one. A title is 「前半 + 接続詞 + 後半」, and each of the
/// three slots is filled from its own list of collectable words.
///
/// The id is what gets stored and what the owned set is keyed by; the text is
/// only ever painted. They are namespaced (`p_` / `c_` / `s_`) because one
/// owned set covers all three lists — see [TitleCatalog.allTitleWordIds].
@immutable
class TitleWord {
  const TitleWord({required this.id, required this.text});

  final String id;
  final String text;
}

/// The words a 称号 can be built from. Pure data, like [ProfileCatalog].
class TitleCatalog {
  const TitleCatalog._();

  static const defaultPrefixId = 'p_nebou';
  static const defaultConnectorId = 'c_no';
  static const defaultSuffixId = 's_joushuuhan';

  static const prefixes = <TitleWord>[
    TitleWord(id: defaultPrefixId, text: '寝坊'),
    TitleWord(id: 'p_hayaoki', text: '早起き'),
    TitleWord(id: 'p_futon', text: '布団'),
    TitleWord(id: 'p_mezamashi', text: '目覚まし'),
    TitleWord(id: 'p_yofukashi', text: '夜更かし'),
    TitleWord(id: 'p_asahi', text: '朝日'),
    TitleWord(id: 'p_nidone', text: '二度寝'),
    TitleWord(id: 'p_kakugo', text: '覚悟'),
  ];

  static const connectors = <TitleWord>[
    TitleWord(id: defaultConnectorId, text: 'の'),
    TitleWord(id: 'c_naru', text: 'なる'),
    TitleWord(id: 'c_taru', text: 'たる'),
  ];

  static const suffixes = <TitleWord>[
    TitleWord(id: defaultSuffixId, text: '常習犯'),
    TitleWord(id: 's_tatsujin', text: '達人'),
    TitleWord(id: 's_bannin', text: '番人'),
    TitleWord(id: 's_chousensha', text: '挑戦者'),
    TitleWord(id: 's_minarai', text: '見習い'),
    TitleWord(id: 's_ou', text: '王'),
    TitleWord(id: 's_juunin', text: '住人'),
    TitleWord(id: 's_shokunin', text: '職人'),
  ];

  /// The whole vocabulary, used as the "owns everything" default until there is
  /// a way to earn a word. Spelled out rather than derived so it can be a
  /// `const` default on `Profile`.
  static const allTitleWordIds = {
    defaultPrefixId,
    'p_hayaoki',
    'p_futon',
    'p_mezamashi',
    'p_yofukashi',
    'p_asahi',
    'p_nidone',
    'p_kakugo',
    defaultConnectorId,
    'c_naru',
    'c_taru',
    defaultSuffixId,
    's_tatsujin',
    's_bannin',
    's_chousensha',
    's_minarai',
    's_ou',
    's_juunin',
    's_shokunin',
  };

  /// How many words there are in total — one half of 所持コレクション数.
  static int get wordCount =>
      prefixes.length + connectors.length + suffixes.length;

  /// Lookups fall back to the first entry rather than throwing, exactly as
  /// [ProfileCatalog] does: a title stored by a future version must still
  /// paint something instead of crashing the profile.
  static TitleWord prefixById(String id) =>
      prefixes.firstWhere((w) => w.id == id, orElse: () => prefixes.first);

  static TitleWord connectorById(String id) =>
      connectors.firstWhere((w) => w.id == id, orElse: () => connectors.first);

  static TitleWord suffixById(String id) =>
      suffixes.firstWhere((w) => w.id == id, orElse: () => suffixes.first);
}

/// 「寝坊」+「の」+「常習犯」→「寝坊の常習犯」. Pure.
///
/// Unknown ids fall back to the first word of their list, so a title can never
/// come out empty or half-written.
String composeTitle(String prefixId, String connectorId, String suffixId) =>
    '${TitleCatalog.prefixById(prefixId).text}'
    '${TitleCatalog.connectorById(connectorId).text}'
    '${TitleCatalog.suffixById(suffixId).text}';
