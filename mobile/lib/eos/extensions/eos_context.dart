import 'package:flutter/material.dart';

import '../tokens/eos_tokens.dart';

extension EosContext on BuildContext {
  EosTokens get eos => Theme.of(this).extension<EosTokens>()!;
  ThemeData get eosTheme => Theme.of(this);
  ColorScheme get eosColors => Theme.of(this).colorScheme;
  TextTheme get eosText => Theme.of(this).textTheme;
}
