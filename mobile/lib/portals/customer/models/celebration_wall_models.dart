// Celebration wall models — Phase 2B.

const wallReactionTypes = ['heart', 'celebrate', 'cheers', 'fire'];

const wallReactionEmoji = <String, String>{
  'heart': '❤️',
  'celebrate': '🎉',
  'cheers': '🥂',
  'fire': '🔥',
};

class WallSettings {
  const WallSettings({required this.liveMode});

  final bool liveMode;

  factory WallSettings.fromJson(Map<String, dynamic> json) {
    return WallSettings(liveMode: json['liveMode'] == true);
  }
}

class WallPost {
  const WallPost({
    required this.id,
    required this.guestName,
    required this.message,
    this.photoUrl,
    required this.status,
    required this.pinned,
    required this.reactions,
    required this.createdAt,
    this.pinnedAt,
  });

  final String id;
  final String guestName;
  final String message;
  final String? photoUrl;
  final String status;
  final bool pinned;
  final Map<String, int> reactions;
  final DateTime createdAt;
  final DateTime? pinnedAt;

  bool get isVisible => status == 'visible';
  bool get isHidden => status == 'hidden';

  int reactionCount(String type) => reactions[type] ?? 0;

  factory WallPost.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    final reactions = <String, int>{};
    if (rawReactions is Map) {
      for (final key in wallReactionTypes) {
        final v = rawReactions[key];
        if (v is num) reactions[key] = v.toInt();
      }
    }
    return WallPost(
      id: (json['id'] ?? '').toString(),
      guestName: (json['guestName'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      photoUrl: json['photoUrl'] as String?,
      status: (json['status'] ?? 'visible').toString(),
      pinned: json['pinned'] == true,
      reactions: reactions,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      pinnedAt: json['pinnedAt'] != null
          ? DateTime.tryParse(json['pinnedAt'].toString())
          : null,
    );
  }
}

class WallSnapshot {
  const WallSnapshot({required this.settings, required this.items});

  final WallSettings settings;
  final List<WallPost> items;

  factory WallSnapshot.fromJson(Map<String, dynamic> json) {
    return WallSnapshot(
      settings: WallSettings.fromJson(json['settings'] as Map<String, dynamic>? ?? const {}),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => WallPost.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory WallSnapshot.publicFromJson(Map<String, dynamic> json) {
    return WallSnapshot(
      settings: WallSettings.fromJson(json['settings'] as Map<String, dynamic>? ?? const {}),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => WallPost.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
