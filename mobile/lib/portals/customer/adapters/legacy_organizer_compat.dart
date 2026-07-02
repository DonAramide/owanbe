/// TEMPORARY compatibility adapter (Phase 42.2).

///

/// Customer Portal must not import `features/organizer/*` directly.

/// All legacy Organizer data, models, and providers are re-exported here

/// until native Customer Event OS abstractions replace them.

@Deprecated(
  'Phase 42.5: Use Customer Event OS under portals/customer/. '
  'See docs/phase42/PHASE42_5_LEGACY_ELIMINATION.md.',
)
library;



export '../../../features/organizer/data/organizer_event_store.dart';

export '../../../features/organizer/data/organizer_persistence.dart';

export '../../../features/organizer/finance/organizer_finance_api.dart';

export '../../../features/organizer/finance/organizer_finance_providers.dart';

export '../../../features/organizer/models/organizer_models.dart';

export '../../../features/organizer/providers/organizer_providers.dart';

export '../../../features/organizer/wizard_v2/event_create_wizard_v2_screen.dart';

