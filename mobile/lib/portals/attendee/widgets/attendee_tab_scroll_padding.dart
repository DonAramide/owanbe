import 'package:flutter/material.dart';

/// Bottom inset for attendee dashboard tabs above the navigation bar.
EdgeInsets attendeeTabScrollPadding(BuildContext context, {double extra = 24}) {
  final viewPadding = MediaQuery.paddingOf(context).bottom;
  return EdgeInsets.only(bottom: kBottomNavigationBarHeight + viewPadding + extra);
}
