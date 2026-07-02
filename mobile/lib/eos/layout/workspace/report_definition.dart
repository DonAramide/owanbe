enum ReportFormat {
  csv,
  excel,
  pdf,
  powerBi,
}

class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.supportedFormats,
  });

  final String id;
  final String title;
  final String description;
  final List<ReportFormat> supportedFormats;
}
