import 'package:flutter/material.dart';

import '../../eos/eos.dart';
import '../validation/profile_validators.dart';

/// Multiline profile text area (bio, notes, etc.).
class ProfileTextArea extends StatelessWidget {
  const ProfileTextArea({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.maxLines = 4,
    this.maxLength = ProfileValidators.maxBio,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final int maxLines;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return EosTextField(
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator ??
          (v) => ProfileValidators.optionalMaxLength(
                v,
                maxLength,
                message: '$label must be $maxLength characters or less',
              ),
    );
  }
}
