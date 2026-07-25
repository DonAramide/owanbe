import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last portal auth failure (Google/email) for UI display.
final authPortalErrorProvider = StateProvider<String?>((ref) => null);
