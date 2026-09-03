import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../eos/eos.dart';

class VendorContactBar extends StatelessWidget {
  const VendorContactBar({
    super.key,
    required this.vendorName,
    required this.phone,
    this.onRequest,
    this.onManage,
    this.requestLabel = 'Request',
  });

  final String vendorName;
  final String phone;
  final VoidCallback? onRequest;
  final VoidCallback? onManage;
  final String requestLabel;

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.eos.spacing.md),
      decoration: BoxDecoration(
        color: EosColors.surface,
        border: Border(top: BorderSide(color: context.eosColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: onManage != null
                  ? FilledButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Manage'),
                    )
                  : FilledButton.icon(
                      onPressed: onRequest,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(requestLabel),
                    ),
            ),
            SizedBox(width: context.eos.spacing.sm),
            IconButton.filledTonal(
              tooltip: 'Call',
              onPressed: () => _copy(context, phone, 'Phone number'),
              icon: const Icon(Icons.phone_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
