import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/vendor_store.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class VendorPayoutsScreen extends ConsumerStatefulWidget {
  const VendorPayoutsScreen({super.key});

  @override
  ConsumerState<VendorPayoutsScreen> createState() => _VendorPayoutsScreenState();
}

class _VendorPayoutsScreenState extends ConsumerState<VendorPayoutsScreen> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(vendorWalletProvider);
    final payouts = ref.watch(vendorPayoutsProvider);

    return EosPageScaffold(
      title: 'Payouts',
      subtitle: 'Transfer earnings to your bank account',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wallet.when(
            data: (snap) => EosSurfaceCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available for payout', style: context.eosText.labelLarge),
                  SizedBox(height: context.eos.spacing.xs),
                  VendorMoneyText(minor: snap.availableMinor),
                  SizedBox(height: context.eos.spacing.md),
                  EosTextField(
                    controller: _amount,
                    label: 'Amount (minor units)',
                    hint: '25000000',
                    keyboardType: TextInputType.number,
                  ),
                  if (_error != null) ...[
                    SizedBox(height: context.eos.spacing.xs),
                    Text(_error!, style: context.eosText.bodySmall?.copyWith(color: EosColors.critical)),
                  ],
                  SizedBox(height: context.eos.spacing.sm),
                  Wrap(
                    spacing: context.eos.spacing.xs,
                    children: [
                      for (final suggestion in _suggestions(snap.availableMinor))
                        ActionChip(
                          label: Text(formatVendorMoney(suggestion)),
                          onPressed: () => _amount.text = suggestion.toString(),
                        ),
                    ],
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: snap.availableMinor <= 0 ? null : _submit,
                      child: const Text('Request payout'),
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Payouts typically settle in 1–2 business days',
                    style: context.eosText.bodySmall,
                  ),
                ],
              ),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          SizedBox(height: context.eos.spacing.xl),
          EosSection(
            title: 'Payout history',
            child: payouts.when(
              data: (list) {
                if (list.isEmpty) {
                  return EosSurfaceCard(child: Text('No payouts yet', style: context.eosText.bodyMedium));
                }
                return Column(
                  children: [
                    for (final p in list)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: EosSurfaceCard(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(context.eos.spacing.sm),
                                decoration: BoxDecoration(
                                  color: context.eosColors.primaryContainer,
                                  borderRadius: context.eos.radius.input,
                                ),
                                child: Icon(Icons.account_balance, color: context.eosColors.primary),
                              ),
                              SizedBox(width: context.eos.spacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    VendorMoneyText(minor: p.amountMinor, compact: true),
                                    Text(p.destinationLabel, style: context.eosText.bodySmall),
                                    Text(formatVendorDate(p.requestedAt), style: context.eosText.labelSmall),
                                  ],
                                ),
                              ),
                              EosFinanceChip(label: p.statusLabel, compact: true),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _suggestions(int available) {
    if (available <= 0) return const [];
    final half = available ~/ 2;
    return {
      available,
      if (half > 0) half,
    }.toList();
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    try {
      VendorStore.instance.requestPayout(amount);
      bumpVendorRevision(ref);
      setState(() {
        _error = null;
        _amount.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }
}
