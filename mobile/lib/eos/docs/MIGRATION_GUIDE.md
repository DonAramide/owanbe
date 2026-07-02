# Migration Guide

Migrating existing screens to the EOS Design System v2.0:
1. Replace standard `ElevatedButton` or `Container` styles with `EosSurfaceCard`.
2. Refactor hardcoded spacings to refer to `EosSpacing`.
3. Resolve theme-derived colors via `context.eosColors`.
