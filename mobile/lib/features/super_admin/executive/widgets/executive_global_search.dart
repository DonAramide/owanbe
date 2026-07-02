import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../super_admin_providers.dart';
import '../executive_dashboard_provider.dart';
import '../models/executive_dashboard_models.dart';

class ExecutiveGlobalSearch extends ConsumerStatefulWidget {
  const ExecutiveGlobalSearch({super.key});

  @override
  ConsumerState<ExecutiveGlobalSearch> createState() => _ExecutiveGlobalSearchState();
}

class _ExecutiveGlobalSearchState extends ConsumerState<ExecutiveGlobalSearch> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(executiveDashboardProvider);
    return data.when(
      data: (bundle) {
        final results = _query.trim().isEmpty
            ? <ExecutiveSearchResult>[]
            : bundle.searchIndex
                .where((r) => '${r.title} ${r.subtitle} ${r.category}'.toLowerCase().contains(_query.toLowerCase()))
                .take(12)
                .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EosSearchField(
              controller: _controller,
              hint: 'Search tenants, events, audit, security…',
              onChanged: (v) => setState(() => _query = v),
            ),
            if (results.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.sm),
              Material(
                elevation: 8,
                borderRadius: context.eos.radius.card,
                color: context.eosColors.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final group in _grouped(results).entries) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(context.eos.spacing.md, context.eos.spacing.sm, context.eos.spacing.md, context.eos.spacing.xs),
                          child: Text(group.key, style: context.eosText.labelLarge),
                        ),
                        for (final r in group.value)
                          ListTile(
                            title: Text(r.title),
                            subtitle: Text(r.subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (r.tenantId != null) {
                                ref.read(selectedSuperAdminTenantIdProvider.notifier).state = r.tenantId;
                              }
                              ref.read(superAdminShellTabProvider.notifier).select(r.tabIndex);
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => EosSearchField(hint: 'Search tenants, events, audit, security…', onChanged: (_) {}),
      error: (_, _) => EosSearchField(hint: 'Search unavailable', onChanged: (_) {}),
    );
  }

  Map<String, List<ExecutiveSearchResult>> _grouped(List<ExecutiveSearchResult> results) {
    final map = <String, List<ExecutiveSearchResult>>{};
    for (final r in results) {
      map.putIfAbsent(r.category, () => []).add(r);
    }
    return map;
  }
}
