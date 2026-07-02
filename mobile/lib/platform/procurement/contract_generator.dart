import 'procurement_models.dart';

class ContractGenerator {
  static String generateLegalDocument(ContractProposal proposal) {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('             B2B SERVICES AGREEMENT               ');
    buffer.writeln('==================================================');
    buffer.writeln('Agreement Ref: ${proposal.id}');
    buffer.writeln('Date: ${proposal.createdAt.toIso8601String()}');
    buffer.writeln('\nPARTIES:');
    buffer.writeln('1. EVENT ORGANIZER: Ref ID [${proposal.organizerId}]');
    buffer.writeln('2. SERVICE VENDOR:   Ref ID [${proposal.vendorId}]');
    buffer.writeln('\nSERVICES & DELIVERABLES:');
    buffer.writeln(proposal.requirements);
    buffer.writeln('\nPAYMENT TERMS (Commerce360 Escrow):');
    buffer.writeln('Total Contract Value: ₦${(proposal.totalAmountMinor / 100).toStringAsFixed(2)}');
    buffer.writeln('\nMILESTONE DISBURSEMENT BREAKDOWN:');
    for (final milestone in proposal.milestones) {
      buffer.writeln('- ${milestone.title}: ₦${(milestone.amountMinor / 100).toStringAsFixed(2)} (${milestone.description})');
    }
    buffer.writeln('\nCLAUSES:');
    buffer.writeln('1. General: Work must be performed in accordance with Nigerian event policies.');
    buffer.writeln('2. Dispute Resolution: Arbitrated directly by platform administrators.');
    buffer.writeln('\n==================================================');
    buffer.writeln('             SIGNATURE CLEARANCE                 ');
    buffer.writeln('==================================================');
    if (proposal.signatures.isEmpty) {
      buffer.writeln('PENDING SIGNATURES');
    } else {
      for (final sig in proposal.signatures) {
        buffer.writeln('Signed by [${sig.signerId}] (${sig.role.toUpperCase()}) on ${sig.signedAt}');
        buffer.writeln('Cryptographic Verification Hash: ${sig.signatureHash}');
      }
    }
    return buffer.toString();
  }
}
