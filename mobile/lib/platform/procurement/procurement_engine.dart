import 'procurement_models.dart';

class ProcurementEngine {
  // Validate state transitions according to standard B2B procurement constraints
  static bool isValidTransition(ProcurementState current, ProcurementState next) {
    switch (current) {
      case ProcurementState.draft:
        return next == ProcurementState.proposed || next == ProcurementState.cancelled;
      case ProcurementState.proposed:
        return next == ProcurementState.signed || next == ProcurementState.cancelled;
      case ProcurementState.signed:
        return next == ProcurementState.active || next == ProcurementState.cancelled;
      case ProcurementState.active:
        return next == ProcurementState.milestoneClaimed || next == ProcurementState.cancelled;
      case ProcurementState.milestoneClaimed:
        return next == ProcurementState.active || next == ProcurementState.completed;
      case ProcurementState.completed:
      case ProcurementState.cancelled:
        return false; // Terminal states
    }
  }

  static ContractProposal transitionProposal(ContractProposal current, ProcurementState nextState) {
    if (!isValidTransition(current.state, nextState)) {
      throw Exception('Illegal Procurement transition from ${current.state} to $nextState');
    }
    return ContractProposal(
      id: current.id,
      organizerId: current.organizerId,
      vendorId: current.vendorId,
      eventId: current.eventId,
      requirements: current.requirements,
      totalAmountMinor: current.totalAmountMinor,
      milestones: current.milestones,
      signatures: current.signatures,
      state: nextState,
      createdAt: current.createdAt,
    );
  }
}
