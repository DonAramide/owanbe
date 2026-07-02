class AssetVersion {
  AssetVersion({
    required this.id,
    required this.assetId,
    required this.versionNumber,
    required this.objectKey,
    required this.checksum,
    required this.size,
    required this.createdBy,
    required this.createdDate,
    required this.changeSummary,
    this.reason,
  });

  final String id;
  final String assetId;
  final int versionNumber;
  final String objectKey;
  final String checksum;
  final int size;
  final String createdBy;
  final DateTime createdDate;
  final String changeSummary;
  final String? reason;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'asset_id': assetId,
      'version_number': versionNumber,
      'object_key': objectKey,
      'checksum': checksum,
      'size': size,
      'created_by': createdBy,
      'created_date': createdDate.toIso8601String(),
      'change_summary': changeSummary,
      'reason': reason,
    };
  }

  factory AssetVersion.fromJson(Map<String, dynamic> json) {
    return AssetVersion(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      versionNumber: json['version_number'] as int,
      objectKey: json['object_key'] as String,
      checksum: json['checksum'] as String,
      size: json['size'] as int,
      createdBy: json['created_by'] as String,
      createdDate: DateTime.parse(json['created_date'] as String),
      changeSummary: json['change_summary'] as String,
      reason: json['reason'] as String?,
    );
  }
}
