import 'package:flutter/material.dart';

import '../../eos/eos.dart';
import '../models/profile_social_link_defs.dart';
import '../validation/profile_validators.dart';

/// Reusable social links form block.
class ProfileSocialLinksForm extends StatelessWidget {
  const ProfileSocialLinksForm({
    super.key,
    required this.controllers,
    this.defs = kDefaultProfileSocialLinkDefs,
    this.enabled = true,
    this.title = 'Social links',
    this.onChanged,
  });

  final Map<String, TextEditingController> controllers;
  final List<ProfileSocialLinkDef> defs;
  final bool enabled;
  final String title;
  final VoidCallback? onChanged;

  static Map<String, TextEditingController> createControllers({
    Map<String, String> initial = const {},
    List<ProfileSocialLinkDef> defs = kDefaultProfileSocialLinkDefs,
  }) {
    return {
      for (final d in defs) d.key: TextEditingController(text: initial[d.key] ?? ''),
    };
  }

  static void disposeControllers(Map<String, TextEditingController> controllers) {
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  static Map<String, String> valuesOf(Map<String, TextEditingController> controllers) {
    return {
      for (final e in controllers.entries) e.key: e.value.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.sm),
        for (final def in defs) ...[
          EosTextField(
            controller: controllers[def.key],
            label: def.label,
            hint: def.hint,
            keyboardType: TextInputType.url,
            enabled: enabled,
            onChanged: onChanged == null ? null : (_) => onChanged!(),
            validator: ProfileValidators.optionalHttpUrl,
          ),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}
