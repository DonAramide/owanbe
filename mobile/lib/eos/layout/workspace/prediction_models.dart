class PredictionModel {
  const PredictionModel({
    required this.target,
    required this.prediction,
    required this.confidence,
    required this.trend,
    required this.businessImpact,
    required this.recommendedAction,
  });

  final String target;
  final String prediction;
  final double confidence;
  final String trend;
  final String businessImpact;
  final String recommendedAction;
}
