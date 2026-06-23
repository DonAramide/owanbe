import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/ai_planner_models.dart';
import '../providers/customer_ai_planner_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/ai_planner/planner_budget_allocation.dart';
import '../widgets/ai_planner/planner_checklist.dart';
import '../widgets/ai_planner/planner_hero_banner.dart';
import '../widgets/ai_planner/planner_input_card.dart';
import '../widgets/ai_planner/planner_missing_requirements.dart';
import '../widgets/ai_planner/planner_recommended_vendors.dart';
import '../widgets/ai_planner/planner_timeline.dart';
import '../widgets/empty_state_card.dart';
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
    ref.read(aiPlannerInputsProvider(widget.eventId).notifier).setInputs(inputs);
    _budgetController.text = inputs.budgetMinor > 0 ? '${inputs.budgetMinor ~/ 100}' : '';
    _guestController.text = inputs.guestCount > 0 ? '${inputs.guestCount}' : '';
    _locationController.text = inputs.location;
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

    return Scaffold(
      backgroundColor: EosColors.canvas,
      appBar: AppBar(
        backgroundColor: EosColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.eventDetail(widget.eventId));
            }
          },
        ),
        title: const Text('AI Event Planner'),
        actions: [
          if (generated)
            IconButton(
              tooltip: 'Regenerate',
              onPressed: _generating ? null : _generate,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: contextAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load event',
              message: error.toString(),
              actionLabel: 'Back to event',
              onAction: () => context.go(CustomerRoutes.eventDetail(widget.eventId)),
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

          return RefreshIndicator(
            onRefresh: () async {
              resetAiPlanner(ref, widget.eventId);
              _initialized = false;
              ref.invalidate(aiPlannerEventContextProvider(widget.eventId));
              await ref.read(aiPlannerEventContextProvider(widget.eventId).future);
            },
            child: ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                SectionHeader(
                  title: ctx.event.title,
                  subtitle: 'Smart planning for your celebration',
                ),
                SizedBox(height: context.eos.spacing.md),
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
                  const SectionHeader(
                    title: 'Missing requirements',
                    subtitle: 'Gaps to close before the big day.',
                  ),
                  PlannerMissingRequirements(items: plan.missingRequirements, eventId: widget.eventId),
                  SizedBox(height: context.eos.spacing.lg),
                  const SectionHeader(
                    title: 'Recommended vendors',
                    subtitle: 'Matched to your event type and location.',
                  ),
                  PlannerRecommendedVendors(vendors: plan.recommendedVendors),
                  SizedBox(height: context.eos.spacing.lg),
                  const SectionHeader(
                    title: 'Budget allocation',
                    subtitle: 'Suggested split across celebration categories.',
                  ),
                  PlannerBudgetAllocation(slices: plan.budgetSlices),
                  SizedBox(height: context.eos.spacing.lg),
                  const SectionHeader(
                    title: 'Planning checklist',
                    subtitle: 'Track what is done and what is next.',
                  ),
                  PlannerChecklist(items: plan.checklist),
                  SizedBox(height: context.eos.spacing.lg),
                  const SectionHeader(
                    title: 'Timeline',
                    subtitle: 'Milestones counting down to your event.',
                  ),
                  PlannerTimeline(items: plan.timeline),
                  SizedBox(height: context.eos.spacing.xl),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
