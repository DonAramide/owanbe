/// Central adaptive breakpoints for the EOS multi-platform layout system.
///
/// Phone (compact):   0 – 599
/// Tablet (medium):   600 – 1023
/// Desktop (expanded): 1024+
/// Wide (density):    1440+
///
/// Screens must not hardcode widths — use [EosResponsive] / [EosAdaptive].
abstract final class EosBreakpoints {
  /// Upper bound exclusive for phone / compact layouts.
  static const double phone = 600;

  /// Alias — tablet / medium layouts begin at [phone].
  static const double tablet = 600;

  /// Desktop / expanded layouts begin here.
  static const double desktop = 1024;

  /// Ultra-wide density layouts begin here.
  static const double wide = 1440;

  /// Legacy alias for [phone].
  static const double mobile = phone;

  /// Max primary bottom-nav destinations before overflow ("More").
  static const int mobilePrimaryNavSlots = 4;
}
