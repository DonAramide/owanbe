/// Owanbe Event Operating System (EOS) — foundational UI architecture.
///
/// Every feature module should import from this library and compose EOS primitives
/// instead of ad-hoc Material widgets.
library eos;

export 'extensions/eos_context.dart';
export 'layout/eos_page_scaffold.dart';
export 'layout/eos_responsive.dart';
export 'layout/eos_section.dart';
export 'navigation/eos_app_shell.dart';
export 'navigation/eos_nav_destination.dart';
export 'navigation/eos_public_shell.dart';
export 'navigation/eos_role_destinations.dart';
export 'theme/eos_theme.dart';
export 'tokens/eos_breakpoints.dart';
export 'tokens/eos_colors.dart';
export 'tokens/eos_radius.dart';
export 'tokens/eos_shadows.dart';
export 'tokens/eos_spacing.dart';
export 'tokens/eos_tokens.dart';
export 'tokens/eos_typography.dart';
export 'widgets/analytics/eos_chart_legend.dart';
export 'widgets/analytics/eos_sparkline.dart';
export 'widgets/analytics/eos_trend_badge.dart';
export 'widgets/attendees/eos_attendee_chip.dart';
export 'widgets/attendees/eos_checkin_status.dart';
export 'widgets/cards/eos_kpi_card.dart';
export 'widgets/cards/eos_surface_card.dart';
export 'widgets/events/eos_event_card.dart';
export 'widgets/events/eos_event_status_badge.dart';
export 'widgets/financial/eos_attention_banner.dart';
export 'widgets/financial/eos_finance_chip.dart';
export 'widgets/financial/eos_money_text.dart';
export 'widgets/forms/eos_search_field.dart';
export 'widgets/forms/eos_select_field.dart';
export 'widgets/forms/eos_text_field.dart';
export 'widgets/monitoring/eos_feed_item.dart';
export 'widgets/monitoring/eos_live_indicator.dart';
export 'widgets/monitoring/eos_status_pulse.dart';
export 'widgets/settings/eos_theme_mode_section.dart';
export 'widgets/tables/eos_data_table.dart';
export 'widgets/vendors/eos_vendor_card.dart';
export 'widgets/vendors/eos_vendor_tier_chip.dart';
