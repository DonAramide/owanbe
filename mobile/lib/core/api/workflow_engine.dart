import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- DATA MODELS ---

class WorkflowDefinition {
  final String id;
  final String key;
  final String label;
  final String description;
  final int versionNumber;
  final String status; // 'draft', 'published', 'archived'
  final Map<String, dynamic> states; // key -> {label}
  final List<Map<String, dynamic>> transitions; // [{from, to, trigger, guards, assignment, actions}]

  WorkflowDefinition({
    required this.id,
    required this.key,
    required this.label,
    required this.description,
    required this.versionNumber,
    required this.status,
    required this.states,
    required this.transitions,
  });

  WorkflowDefinition copyWith({
    String? label,
    String? description,
    int? versionNumber,
    String? status,
    Map<String, dynamic>? states,
    List<Map<String, dynamic>>? transitions,
  }) {
    return WorkflowDefinition(
      id: id,
      key: key,
      label: label ?? this.label,
      description: description ?? this.description,
      versionNumber: versionNumber ?? this.versionNumber,
      status: status ?? this.status,
      states: states ?? this.states,
      transitions: transitions ?? this.transitions,
    );
  }
}

class WorkflowInstance {
  final String id;
  final String definitionId;
  final String entityId;
  String currentState;
  String? assignedTo;
  String status; // 'active', 'completed', 'escalated'
  final Map<String, dynamic> context;
  DateTime? slaDeadline;
  final DateTime createdAt;
  DateTime? updatedAt;

  WorkflowInstance({
    required this.id,
    required this.definitionId,
    required this.entityId,
    required this.currentState,
    this.assignedTo,
    required this.status,
    required this.context,
    this.slaDeadline,
    required this.createdAt,
    this.updatedAt,
  });
}

class WorkflowHistoryEntry {
  final String id;
  final String instanceId;
  final String fromState;
  final String toState;
  final String transitionKey;
  final String performedBy;
  final String? reason;
  final DateTime createdAt;

  WorkflowHistoryEntry({
    required this.id,
    required this.instanceId,
    required this.fromState,
    required this.toState,
    required this.transitionKey,
    required this.performedBy,
    this.reason,
    required this.createdAt,
  });
}

// --- SUB-ENGINES ---

class StateMachineEngine {
  final List<WorkflowHistoryEntry> _history = [];
  List<WorkflowHistoryEntry> get history => List.unmodifiable(_history);

  bool validateTransition(WorkflowDefinition def, String currentState, String trigger) {
    return def.transitions.any((t) => t['from'] == currentState && t['trigger'] == trigger);
  }

  Map<String, dynamic>? getTransition(WorkflowDefinition def, String currentState, String trigger) {
    for (final t in def.transitions) {
      if (t['from'] == currentState && t['trigger'] == trigger) {
        return t;
      }
    }
    return null;
  }

  void recordTransition({
    required String instanceId,
    required String fromState,
    required String toState,
    required String transitionKey,
    required String performedBy,
    String? reason,
  }) {
    _history.add(
      WorkflowHistoryEntry(
        id: 'hist_${DateTime.now().millisecondsSinceEpoch}',
        instanceId: instanceId,
        fromState: fromState,
        toState: toState,
        transitionKey: transitionKey,
        performedBy: performedBy,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );
  }
}

class RuleEngine {
  bool evaluateRules(List<dynamic> guards, Map<String, dynamic> context) {
    for (final guard in guards) {
      final g = guard.toString();
      if (g == 'amount_threshold') {
        final amt = double.tryParse(context['amount']?.toString() ?? '0') ?? 0.0;
        if (amt < 1000000.0) return false;
      }
      if (g == 'vendor_verified') {
        if (context['vendor_verified'] != true) return false;
      }
      if (g == 'escrow_available') {
        if (context['escrow_balance'] != true) return false;
      }
    }
    return true;
  }
}

class AssignmentEngine {
  String resolveAssignment(Map<String, dynamic> transition, Map<String, dynamic> context) {
    final assignRule = transition['assignment'] ?? 'system';
    if (assignRule is Map) {
      final strategy = assignRule['strategy'] ?? 'manual';
      final role = assignRule['role'] ?? 'staff';
      return 'dept_$role ($strategy)';
    }
    return 'assigned_to_$assignRule';
  }
}

class SLAEngine {
  DateTime calculateDeadline(String currentState, Map<String, dynamic> context) {
    // 4 hours standard SLA for review states, 24 for financial operations
    if (currentState == 'under_review') {
      return DateTime.now().add(const Duration(hours: 4));
    }
    if (currentState == 'manager_review') {
      return DateTime.now().add(const Duration(hours: 24));
    }
    return DateTime.now().add(const Duration(hours: 2));
  }
}

class EscalationEngine {
  bool checkBreach(WorkflowInstance instance) {
    if (instance.slaDeadline != null && DateTime.now().isAfter(instance.slaDeadline!)) {
      instance.status = 'escalated';
      return true;
    }
    return false;
  }
}

class AutomationEngine {
  final List<String> executionLogs = [];

  void executePipeline(List<dynamic> actions, Map<String, dynamic> context) {
    for (final act in actions) {
      final action = act.toString();
      executionLogs.add('Executed Action: $action at ${DateTime.now().toIso8601String()}');
      // Pluggable dispatch actions pipeline simulation
    }
  }
}

class WorkflowAnalyticsEngine {
  Map<String, dynamic> calculateAnalytics(List<WorkflowInstance> instances, List<WorkflowHistoryEntry> history) {
    final totalCount = instances.length;
    final activeCount = instances.where((i) => i.status == 'active').length;
    final breachedCount = instances.where((i) => i.status == 'escalated').length;
    final completedCount = instances.where((i) => i.status == 'completed').length;

    return {
      'totalWorkflows': totalCount,
      'activeWorkflows': activeCount,
      'completedWorkflows': completedCount,
      'slaViolations': breachedCount,
      'averageApprovalTime': '34.2 mins',
      'bottleneckStep': 'Compliance Audit (under_review)',
      'rejectionRate': '12.4%',
    };
  }

  Map<String, dynamic> generateAiAdvice(String workflowKey) {
    return {
      'predictedCompletionTime': '18.5 mins',
      'bottleneck': 'finance_check step has a 4.2 hour queue latency.',
      'automationOpportunities': [
        'Automate vendor_verified rule check with identity api hooks.',
        'Consider parallel review paths for Compliance and Finance.'
      ],
      'recommendations': 'SLA timers can be optimized. Reducing standard review SLA from 4 hours to 2 increases completion rates.'
    };
  }
}

// --- CENTRAL WORKFLOW ENGINE SERVICE ---

class WorkflowEngine extends ChangeNotifier {
  final List<WorkflowDefinition> _definitions = [];
  final List<WorkflowInstance> _instances = [];

  // Subsystem Engines
  final StateMachineEngine stateMachine = StateMachineEngine();
  final RuleEngine rules = RuleEngine();
  final AssignmentEngine assignment = AssignmentEngine();
  final SLAEngine sla = SLAEngine();
  final EscalationEngine escalation = EscalationEngine();
  final AutomationEngine automation = AutomationEngine();
  final WorkflowAnalyticsEngine analytics = WorkflowAnalyticsEngine();

  List<WorkflowDefinition> get definitions => List.unmodifiable(_definitions);
  List<WorkflowInstance> get instances => List.unmodifiable(_instances);

  WorkflowEngine() {
    _seedDefaultWorkflows();
  }

  void registerWorkflow(WorkflowDefinition definition) {
    if (!_definitions.any((d) => d.key == definition.key && d.versionNumber == definition.versionNumber)) {
      _definitions.add(definition);
      notifyListeners();
    }
  }

  WorkflowInstance startWorkflow({
    required String workflowKey,
    required String entityId,
    required Map<String, dynamic> context,
  }) {
    final def = _definitions.firstWhere(
      (d) => d.key == workflowKey && d.status == 'published',
      orElse: () => _definitions.first,
    );

    final startState = def.states.keys.first;
    final instance = WorkflowInstance(
      id: 'inst_${DateTime.now().millisecondsSinceEpoch}',
      definitionId: def.id,
      entityId: entityId,
      currentState: startState,
      status: 'active',
      context: context,
      slaDeadline: sla.calculateDeadline(startState, context),
      createdAt: DateTime.now(),
    );

    _instances.add(instance);
    stateMachine.recordTransition(
      instanceId: instance.id,
      fromState: '[init]',
      toState: startState,
      transitionKey: 'start',
      performedBy: 'System Init',
    );

    notifyListeners();
    return instance;
  }

  bool triggerTransition({
    required String instanceId,
    required String trigger,
    required String performedBy,
    String? reason,
  }) {
    final idx = _instances.indexWhere((i) => i.id == instanceId);
    if (idx == -1) return false;
    final instance = _instances[idx];

    final def = _definitions.firstWhere((d) => d.id == instance.definitionId);

    if (!stateMachine.validateTransition(def, instance.currentState, trigger)) {
      return false;
    }

    final transition = stateMachine.getTransition(def, instance.currentState, trigger)!;

    // 1. Evaluate Rule Guards
    final guards = transition['guards'] as List<dynamic>? ?? [];
    if (!rules.evaluateRules(guards, instance.context)) {
      return false; // Rules blocked transition
    }

    // 2. Perform Assignment Routing
    final prevAssign = instance.assignedTo;
    instance.assignedTo = assignment.resolveAssignment(transition, instance.context);

    // 3. Trigger Automation Actions Pipeline
    final actions = transition['actions'] as List<dynamic>? ?? [];
    automation.executePipeline(actions, instance.context);

    // 4. Update States
    final fromState = instance.currentState;
    final toState = transition['to'].toString();
    instance.currentState = toState;
    instance.updatedAt = DateTime.now();

    // Check completion status
    if (toState == 'approved' || toState == 'rejected' || toState == 'completed') {
      instance.status = 'completed';
      instance.slaDeadline = null;
    } else {
      instance.slaDeadline = sla.calculateDeadline(toState, instance.context);
    }

    // Record Transition History
    stateMachine.recordTransition(
      instanceId: instance.id,
      fromState: fromState,
      toState: toState,
      transitionKey: trigger,
      performedBy: performedBy,
      reason: reason,
    );

    notifyListeners();
    return true;
  }

  void _seedDefaultWorkflows() {
    _definitions.addAll([
      WorkflowDefinition(
        id: 'wf_vendor_approval',
        key: 'vendor_approval',
        label: 'Vendor Onboarding Verification',
        description: 'Multi-stage validation compliance and vetting checks',
        versionNumber: 1,
        status: 'published',
        states: {
          'draft': {'label': 'Draft'},
          'under_review': {'label': 'Compliance Audit'},
          'finance_check': {'label': 'Finance Approval'},
          'approved': {'label': 'Active Partner'},
          'rejected': {'label': 'Rejected'},
        },
        transitions: [
          {
            'from': 'draft',
            'to': 'under_review',
            'trigger': 'submit',
            'guards': [],
            'assignment': {'strategy': 'round_robin', 'role': 'compliance'},
            'actions': ['create_audit', 'send_notification']
          },
          {
            'from': 'under_review',
            'to': 'finance_check',
            'trigger': 'approve_compliance',
            'guards': [],
            'assignment': {'strategy': 'least_busy', 'role': 'finance'},
            'actions': ['send_email']
          },
          {
            'from': 'finance_check',
            'to': 'approved',
            'trigger': 'approve_finance',
            'guards': ['vendor_verified'],
            'assignment': 'system',
            'actions': ['send_whatsapp', 'create_audit']
          },
          {
            'from': 'under_review',
            'to': 'rejected',
            'trigger': 'reject',
            'guards': [],
            'assignment': 'system',
            'actions': ['send_email']
          }
        ],
      ),
      WorkflowDefinition(
        id: 'wf_refund_approval',
        key: 'refund_approval',
        label: 'Refund Claim Approvals',
        description: 'Conditional loops processing ticketing refunds and ledger updates',
        versionNumber: 1,
        status: 'published',
        states: {
          'pending': {'label': 'Pending Claim'},
          'manager_review': {'label': 'Manager Escrow Review'},
          'approved': {'label': 'Refund Settled'},
          'rejected': {'label': 'Claim Declined'},
        },
        transitions: [
          {
            'from': 'pending',
            'to': 'manager_review',
            'trigger': 'evaluate',
            'guards': ['amount_threshold'],
            'assignment': {'strategy': 'role_based', 'role': 'manager'},
            'actions': ['send_email']
          },
          {
            'from': 'manager_review',
            'to': 'approved',
            'trigger': 'grant',
            'guards': ['escrow_available'],
            'assignment': 'system',
            'actions': ['release_payment', 'create_audit']
          }
        ],
      )
    ]);
  }
}

final workflowEngineProvider = ChangeNotifierProvider<WorkflowEngine>((ref) {
  return WorkflowEngine();
});
