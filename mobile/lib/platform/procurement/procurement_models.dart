enum ProcurementState {
  draft,
  proposed,
  signed,
  active,
  milestoneClaimed,
  completed,
  cancelled,
}

enum MilestoneStatus {
  pending,
  locked,
  released,
  disputed,
}

class ContractMilestone {
  final String id;
  final String title;
  final int amountMinor;
  final MilestoneStatus status;
  final String description;

  ContractMilestone({
    required this.id,
    required this.title,
    required this.amountMinor,
    required this.status,
    required this.description,
  });
}

class ContractSignature {
  final String signerId;
  final String role; // organizer, vendor
  final DateTime signedAt;
  final String signatureHash;

  ContractSignature({
    required this.signerId,
    required this.role,
    required this.signedAt,
    required this.signatureHash,
  });
}

class ContractProposal {
  final String id;
  final String organizerId;
  final String vendorId;
  final String eventId;
  final String requirements;
  final int totalAmountMinor;
  final List<ContractMilestone> milestones;
  final List<ContractSignature> signatures;
  final ProcurementState state;
  final DateTime createdAt;

  ContractProposal({
    required this.id,
    required this.organizerId,
    required this.vendorId,
    required this.eventId,
    required this.requirements,
    required this.totalAmountMinor,
    required this.milestones,
    required this.signatures,
    required this.state,
    required this.createdAt,
  });
}
