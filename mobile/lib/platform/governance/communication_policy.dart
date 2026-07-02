import 'governance_models.dart';

class CommunicationPolicy {
  final Map<String, PolicyPermission> channels;
  final Map<String, bool> permittedPairings; // e.g., 'organizer_vendor', 'vendor_vendor'
  final Map<String, String> restrictions; // specific context restrictions

  CommunicationPolicy({
    required this.channels,
    required this.permittedPairings,
    required this.restrictions,
  });

  factory CommunicationPolicy.defaults() {
    return CommunicationPolicy(
      channels: {
        'messaging': PolicyPermission.enabled,
        'voiceCalling': PolicyPermission.enabled,
        'videoCalling': PolicyPermission.enabled,
        'fileSharing': PolicyPermission.enabled,
        'imageSharing': PolicyPermission.enabled,
        'documentSharing': PolicyPermission.enabled,
        'voiceNotes': PolicyPermission.enabled,
        'screenSharing': PolicyPermission.disabled,
        'typingIndicator': PolicyPermission.enabled,
        'readReceipts': PolicyPermission.enabled,
        'presence': PolicyPermission.enabled,
        'sms': PolicyPermission.enabled,
        'whatsapp': PolicyPermission.enabled,
        'email': PolicyPermission.enabled,
      },
      permittedPairings: {
        'organizer_vendor': true,
        'vendor_vendor': true,
        'attendee_vendor': true,
        'admin_vendor': true,
        'support_vendor': true,
      },
      restrictions: {},
    );
  }

  bool isPairingAllowed(String sourceRole, String targetRole) {
    final key = '${sourceRole.toLowerCase()}_${targetRole.toLowerCase()}';
    return permittedPairings[key] ?? false;
  }

  PolicyPermission getChannelStatus(String channelName) {
    return channels[channelName] ?? PolicyPermission.disabled;
  }
}
