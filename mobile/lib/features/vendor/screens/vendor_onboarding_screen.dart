import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/onboarding_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../eos/widgets/owanbe_logo.dart';

class VendorOnboardingScreen extends ConsumerStatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  ConsumerState<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends ConsumerState<VendorOnboardingScreen> {
  final _legalName = TextEditingController();
  final _tradingName = TextEditingController();
  final _city = TextEditingController();
  final _website = TextEditingController();
  final _countryCode = TextEditingController(text: 'NG');

  var _step = 0;
  var _busy = false;
  String? _applicationId;
  String? _status;
  String? _error;

  static const _vendorId = OnboardingApi.devVendorId;

  @override
  void dispose() {
    _legalName.dispose();
    _tradingName.dispose();
    _city.dispose();
    _website.dispose();
    _countryCode.dispose();
    super.dispose();
  }

  Future<void> _startApplication() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final app = await ref.read(onboardingApiProvider).createApplication(_vendorId);
      setState(() {
        _applicationId = app.id;
        _status = app.status;
        _step = 1;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBusiness() async {
    final appId = _applicationId;
    if (appId == null) return;
    if (_legalName.text.trim().isEmpty) {
      setState(() => _error = 'Legal business name is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(onboardingApiProvider).upsertBusiness(
            vendorId: _vendorId,
            applicationId: appId,
            legalName: _legalName.text.trim(),
            tradingName: _tradingName.text.trim().isEmpty ? null : _tradingName.text.trim(),
            countryCode: _countryCode.text.trim().toUpperCase(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            websiteUrl: _website.text.trim().isEmpty ? null : _website.text.trim(),
          );
      setState(() => _step = 2);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final appId = _applicationId;
    if (appId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final app = await ref.read(onboardingApiProvider).submit(
            vendorId: _vendorId,
            applicationId: appId,
          );
      setState(() {
        _status = app.status;
        _step = 3;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor onboarding'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/vendor'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          const Center(child: OwanbeLogo(size: 72)),
          SizedBox(height: context.eos.spacing.lg),
          Text('Join the Owanbe marketplace', style: context.eosText.headlineSmall),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            'Submit your business profile for review. Once approved, you can receive event requests and manage bookings.',
            style: context.eosText.bodyMedium,
          ),
          SizedBox(height: context.eos.spacing.lg),
          if (_error != null) ...[
            Text(_error!, style: context.eosText.bodySmall?.copyWith(color: context.eosColors.error)),
            SizedBox(height: context.eos.spacing.md),
          ],
          if (_step == 0) ...[
            FilledButton(
              onPressed: _busy ? null : _startApplication,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Start application'),
            ),
          ],
          if (_step >= 1) ...[
            EosTextField(controller: _legalName, label: 'Legal name', hint: 'Jollof & Co Ltd'),
            SizedBox(height: context.eos.spacing.md),
            EosTextField(controller: _tradingName, label: 'Trading name', hint: 'Jollof & Co'),
            SizedBox(height: context.eos.spacing.md),
            EosTextField(controller: _city, label: 'City', hint: 'Lagos'),
            SizedBox(height: context.eos.spacing.md),
            EosTextField(controller: _countryCode, label: 'Country code', hint: 'NG'),
            SizedBox(height: context.eos.spacing.md),
            EosTextField(controller: _website, label: 'Website', hint: 'https://'),
            if (_step == 1) ...[
              SizedBox(height: context.eos.spacing.lg),
              FilledButton(
                onPressed: _busy ? null : _saveBusiness,
                child: const Text('Save & continue'),
              ),
            ],
          ],
          if (_step == 2) ...[
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Submit for review'),
            ),
          ],
          if (_step == 3) ...[
            SizedBox(height: context.eos.spacing.lg),
            EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Application submitted', style: context.eosText.titleMedium),
                  SizedBox(height: context.eos.spacing.sm),
                  Text('Status: ${_status ?? 'under_review'}', style: context.eosText.bodyMedium),
                  SizedBox(height: context.eos.spacing.md),
                  FilledButton(
                    onPressed: () => context.go('/vendor'),
                    child: const Text('Back to vendor portal'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
