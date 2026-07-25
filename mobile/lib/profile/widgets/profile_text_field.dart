import 'package:flutter/material.dart';

import '../../eos/eos.dart';
import '../validation/profile_validators.dart';

/// Profile text field wrapping [EosTextField] with shared validators.
class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.isRequired = false,
    this.maxLength = ProfileValidators.maxShortText,
    this.keyboardType,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final bool isRequired;
  final int maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return EosTextField(
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator ??
          (v) {
            if (isRequired) {
              return ProfileValidators.requiredMaxLength(v, maxLength, label: label);
            }
            return ProfileValidators.optionalMaxLength(v, maxLength);
          },
    );
  }
}
