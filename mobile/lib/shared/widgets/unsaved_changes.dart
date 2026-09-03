import 'package:flutter/material.dart';

/// Shared leave-guard for explicit-save screens. Stay keeps drafts; Discard
/// restores the last persisted values and does not call an API.
class UnsavedChangesBinder {
  UnsavedChangesBinder({required this.isDirty, required this.discard});

  final bool Function() isDirty;
  final VoidCallback discard;
}

class UnsavedChangesRegistry {
  static UnsavedChangesBinder? adminCapabilityDetail;
  static UnsavedChangesBinder? vendorServices;
  static UnsavedChangesBinder? eventDetails;

  static Future<bool>? _inFlight;

  static Future<bool> confirmLeave(
    BuildContext context, {
    required UnsavedChangesBinder? binder,
  }) {
    final current = _inFlight;
    if (current != null) return current;
    final future = _confirmLeave(context, binder);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  static Future<bool> _confirmLeave(
    BuildContext context,
    UnsavedChangesBinder? binder,
  ) async {
    if (binder == null || !binder.isDirty()) return true;
    final discard = await confirmDiscardUnsavedChanges(context);
    if (discard) binder.discard();
    if (discard) await WidgetsBinding.instance.endOfFrame;
    return discard;
  }
}

Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('You have unsaved changes.'),
      content: const Text('Discard these changes? They will not be saved.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Discard Changes'),
        ),
      ],
    ),
  );
  return discard == true;
}
