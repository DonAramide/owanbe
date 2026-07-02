import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/ai_planner_models.dart';
import '../providers/customer_ai_planner_providers.dart';
import '../navigation/event_navigator.dart';
import '../widgets/ai_planner/planner_budget_allocation.dart';
import '../widgets/ai_planner/planner_checklist.dart';
import '../widgets/ai_planner/planner_hero_banner.dart';
import '../widgets/ai_planner/planner_input_card.dart';
import '../widgets/ai_planner/planner_missing_requirements.dart';
import '../widgets/ai_planner/planner_recommended_vendors.dart';
import '../widgets/ai_planner/planner_rental_recommendations.dart';
import '../widgets/ai_planner/planner_timeline.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/section_header.dart';

/// AI Event Planner at `/events/:eventId/ai-planner`.
class CustomerEventAiPlannerScreen extends ConsumerStatefulWidget {
  const CustomerEventAiPlannerScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventAiPlannerScreen> createState() => _CustomerEventAiPlannerScreenState();
}

class _CustomerEventAiPlannerScreenState extends ConsumerState<CustomerEventAiPlannerScreen> {
  late final TextEditingController _budgetController;
  late final TextEditingController _guestController;
  late final TextEditingController _locationController;
  var _generating = false;
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    _guestController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _guestController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _seedInputs(AiPlannerInputs inputs) {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(aiPlannerInputsProvider(widget.eventId).notifier).setInputs(inputs);
      _budgetController.text = inputs.budgetMinor > 0 ? '${inputs.budgetMinor ~/ 100}' : '';
      _guestController.text = inputs.guestCount > 0 ? '${inputs.guestCount}' : '';
      _locationController.text = inputs.location;
    });
  }

  Future<void> _generate() async {
    final inputs = ref.read(aiPlannerInputsProvider(widget.eventId));
    if (inputs == null) return;

    setState(() => _generating = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    ref.read(aiPlannerGeneratedProvider(widget.eventId).notifier).state = true;
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(aiPlannerEventContextProvider(widget.eventId));
    final inputs = ref.watch(aiPlannerInputsProvider(widget.eventId));
    final plan = ref.watch(aiPlannerPlanProvider(widget.eventId));
    final generated = ref.watch(aiPlannerGeneratedProvider(widget.eventId));

    return EventModuleScaffold(
      eventId: widget.eventId,
      title: 'AI Event Planner',
      subtitle: 'Smart planning for your celebration',
      actions: [
        if (generated)
          IconButton(
            tooltip: 'Regenerate',
            onPressed: _generating ? null : _generate,
            icon: const Icon(Icons.refresh),
          ),
      ],
      body: contextAsync.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'AI planner',
              onRetry: () {
                resetAiPlanner(ref, widget.eventId);
                _initialized = false;
                ref.invalidate(aiPlannerEventContextProvider(widget.eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
            ),
          ],
        ),
        data: (ctx) {
          final defaults = defaultInputsFromEvent(
            ctx.event,
            budgetMinor: ctx.budgetMinor > 0 ? ctx.budgetMinor : null,
          );
          _seedInputs(defaults);

          final currentInputs = inputs ?? defaults;

          return EventModuleScrollBody(
            onRefresh: () async {
              resetAiPlanner(ref, widget.eventId);
              _initialized = false;
              ref.invalidate(aiPlannerEventContextProvider(widget.eventId));
              await ref.read(aiPlannerEventContextProvider(widget.eventId).future);
            },
            hero: SectionHeader(
              title: ctx.event.title,
              subtitle: 'Smart planning for your celebration',
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlannerHeroBanner(
                  readinessScore: plan?.readinessScore ?? 0,
                  summary: plan?.summary ?? '',
                  visible: generated && plan != null,
                ),
                SizedBox(height: context.eos.spacing.lg),
                PlannerInputCard(
                  inputs: currentInputs,
                  budgetController: _budgetController,
                  guestController: _guestController,
                  locationController: _locationController,
                  generating: _generating,
                  onEventTypeChanged: (type) {
                    ref.read(aiPlannerInputsProvider(widget.eventId).notifier).update(
                          (s) => s.copyWith(eventType: type),
                        );
                  },
                  onBudgetChanged: (minor) {
                    ref.read(aiPlannerInputsProvider(widget.eventId).notifier).update(
                          (s) => s.copyWith(budgetMinor: minor),
                        );
                  },
                  onGuestCountChanged: (count) {
                    ref.read(aiPlannerInputsProvider(widget.eventId).notifier).update(
                          (s) => s.copyWith(guestCount: count),
                        );
                  },
                  onLocationChanged: (loc) {
                    ref.read(aiPlannerInputsProvider(widget.eventId).notifier).update(
                          (s) => s.copyWith(location: loc),
                        );
                  },
                  onGenerate: _generate,
                ),
                if (generated && plan != null) ...[
                  SizedBox(height: context.eos.spacing.lg),
                  EosSection(
                    title: 'Missing requirements',
                    subtitle: 'Gaps to close before the big day.',
                    child: PlannerMissingRequirements(items: plan.missingRequirements, eventId: widget.eventId),
                  ),
                  EosSection(
                    title: 'Recommended vendors',
                    subtitle: 'Matched to your event type and location.',
                    child: PlannerRecommendedVendors(vendors: plan.recommendedVendors),
                  ),
                  EosSection(
                    title: 'Rental equipment',
                    subtitle: 'Suggested quantities from guest count, event type, and venue.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PlannerRentalRecommendations(items: plan.rentalRecommendations),
                        SizedBox(height: context.eos.spacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => context.eventNav.openRentals(widget.eventId),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Open equipment & rentals'),
                        ),
                      ],
                    ),
                  ),
                  EosSection(
                    title: 'Budget allocation',
                    subtitle: 'Suggested split across celebration categories.',
                    child: PlannerBudgetAllocation(slices: plan.budgetSlices),
                  ),
                  EosSection(
                    title: 'Planning checklist',
                    subtitle: 'Track what is done and what is next.',
                    child: PlannerChecklist(items: plan.checklist),
                  ),
                  EosSection(
                    title: 'Timeline',
                    subtitle: 'Milestones counting down to your event.',
                    child: PlannerTimeline(items: plan.timeline),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
