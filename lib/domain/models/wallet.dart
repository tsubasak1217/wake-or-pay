import 'package:flutter/foundation.dart';

@immutable
class Wallet {
  const Wallet({this.coins = 0, this.tokens = 0});

  final int coins;
  final int tokens;

  Wallet copyWith({int? coins, int? tokens}) =>
      Wallet(coins: coins ?? this.coins, tokens: tokens ?? this.tokens);

  Map<String, dynamic> toJson() => {'coins': coins, 'tokens': tokens};

  factory Wallet.fromJson(Map<String, dynamic> json) =>
      Wallet(coins: json['coins'] as int, tokens: json['tokens'] as int);

  @override
  bool operator ==(Object other) =>
      other is Wallet && other.coins == coins && other.tokens == tokens;

  @override
  int get hashCode => Object.hash(coins, tokens);

  @override
  String toString() => 'Wallet(coins $coins, tokens $tokens)';
}
