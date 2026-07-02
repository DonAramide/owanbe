class SecurityScore {
  const SecurityScore({
    required this.score,
    required this.status,
  });

  final int score;
  final String status;
}

class ThreatModel {
  const ThreatModel({
    required this.id,
    required this.name,
    required this.severity,
    required this.confidence,
    required this.sourceIp,
    required this.affectedTenant,
    required this.affectedUser,
    required this.detectedAt,
    required this.recommendedAction,
    required this.status,
  });

  final String id;
  final String name;
  final String severity;
  final double confidence;
  final String sourceIp;
  final String affectedTenant;
  final String affectedUser;
  final String detectedAt;
  final String recommendedAction;
  final String status;
}

class SecurityIncidentModel {
  const SecurityIncidentModel({
    required this.id,
    required this.title,
    required this.status,
    required this.severity,
    required this.slaHours,
    required this.mttrMinutes,
  });

  final String id;
  final String title;
  final String status;
  final String severity;
  final int slaHours;
  final int mttrMinutes;
}

class FraudModel {
  const FraudModel({
    required this.id,
    required this.type,
    required this.riskScore,
    required this.amountMinor,
    required this.status,
  });

  final String id;
  final String type;
  final int riskScore;
  final int amountMinor;
  final String status;
}

class ComplianceModel {
  const ComplianceModel({
    required this.standard,
    required this.score,
    required this.status,
  });

  final String standard;
  final int score;
  final String status;
}

class RiskModel {
  const RiskModel({
    required this.category,
    required this.score,
    required this.status,
  });

  final String category;
  final int score;
  final String status;
}

class IdentityModel {
  const IdentityModel({
    required this.userId,
    required this.displayName,
    required this.mfaEnabled,
    required this.status,
  });

  final String userId;
  final String displayName;
  final bool mfaEnabled;
  final String status;
}

class SessionModel {
  const SessionModel({
    required this.sessionId,
    required this.userId,
    required this.ipAddress,
    required this.device,
    required this.status,
  });

  final String sessionId;
  final String userId;
  final String ipAddress;
  final String device;
  final String status;
}

class SecurityInsight {
  const SecurityInsight({
    required this.id,
    required this.severity,
    required this.confidence,
    required this.reason,
    required this.businessImpact,
    required this.financialRiskMinor,
    required this.recommendation,
  });

  final String id;
  final String severity;
  final double confidence;
  final String reason;
  final String businessImpact;
  final int financialRiskMinor;
  final String recommendation;
}
