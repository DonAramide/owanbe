import 'package:flutter/material.dart';

import '../../eos/eos.dart';
import '../controllers/profile_edit_controller.dart';
import 'profile_validation_message.dart';

/// Reusable profile edit chrome: header, save/cancel, loading, error, dirty warning.
///
/// Does not own field content — pass [children] for profile-specific fields.
class ProfileEditLayout extends StatelessWidget {
  const ProfileEditLayout({
    super.key,
    required this.title,
    required this.controller,
    required this.formKey,
    required this.children,
    required this.onSave,
    required this.onCancel,
    this.subtitle,
    this.scrollController,
    this.saveLabel = 'Save profile',
    this.cancelLabel = 'Cancel',
    this.showCancel = true,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final ProfileEditController controller;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final ScrollController? scrollController;
  final String saveLabel;
  final String cancelLabel;
  final bool showCancel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final saving = controller.isSaving;
        return PopScope(
          canPop: !controller.isDirty || saving,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || saving) return;
            final discard = await showDiscardChangesDialog(context);
            if (discard && context.mounted) onCancel();
          },
          child: Form(
            key: formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                context.eos.spacing.lg,
                context.eos.spacing.sm,
                context.eos.spacing.lg,
                context.eos.spacing.xl,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.eosText.titleLarge),
                          if (subtitle != null) ...[
                            SizedBox(height: context.eos.spacing.xxs),
                            Text(subtitle!, style: context.eosText.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    if (controller.isDirty && !saving)
                      Padding(
                        padding: EdgeInsets.only(left: context.eos.spacing.sm, top: 4),
                        child: Text(
                          'Unsaved',
                          style: context.eosText.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                ...children,
                if (controller.hasError) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  ProfileValidationMessage(message: controller.errorMessage!),
                ],
                SizedBox(height: context.eos.spacing.lg),
                FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(saveLabel),
                ),
                if (showCancel) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (controller.isDirty) {
                              final discard = await showDiscardChangesDialog(context);
                              if (!discard) return;
                            }
                            onCancel();
                          },
                    child: Text(cancelLabel),
                  ),
                ],
                if (footer != null) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  footer!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('You have unsaved profile changes.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep editing')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard')),
      ],
    ),
  );
  return result ?? false;
}

/// Opens a profile editor as a modal bottom sheet with shared chrome.
Future<T?> showProfileEditSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController scrollController) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.55,
          maxChildSize: 0.98,
          builder: (context, scrollController) => builder(context, scrollController),
        ),
      );
    },
  );
}
