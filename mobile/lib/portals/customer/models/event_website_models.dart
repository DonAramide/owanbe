/// Event website builder configuration (Phase 2A).
class EventWebsiteConfig {
  const EventWebsiteConfig({
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.templateId,
    required this.publicSlug,
    required this.publicUrl,
    required this.themeColor,
    required this.fontPair,
    required this.coverImageUrl,
    required this.heroImageUrl,
    required this.sections,
    required this.publishedAt,
    required this.updatedAt,
  });

  final String eventId;
  final String eventTitle;
  final String status;
  final String templateId;
  final String publicSlug;
  final String publicUrl;
  final String themeColor;
  final String fontPair;
  final String? coverImageUrl;
  final String? heroImageUrl;
  final Map<String, bool> sections;
  final String? publishedAt;
  final String updatedAt;

  bool get isPublished => status == 'published';

  factory EventWebsiteConfig.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final sections = <String, bool>{};
    if (sectionsRaw is Map) {
      for (final entry in sectionsRaw.entries) {
        if (entry.value is bool) {
          sections[entry.key.toString()] = entry.value as bool;
        }
      }
    }
    for (final key in EventWebsiteSectionKeys.all) {
      sections.putIfAbsent(key, () => EventWebsiteSectionKeys.defaults[key] ?? false);
    }
    return EventWebsiteConfig(
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      templateId: json['templateId'] as String? ?? 'wedding_classic',
      publicSlug: json['publicSlug'] as String? ?? '',
      publicUrl: json['publicUrl'] as String? ?? '',
      themeColor: json['themeColor'] as String? ?? '#4B2C6F',
      fontPair: json['fontPair'] as String? ?? 'playfair_lato',
      coverImageUrl: json['coverImageUrl'] as String?,
      heroImageUrl: json['heroImageUrl'] as String?,
      sections: sections,
      publishedAt: json['publishedAt'] as String?,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  EventWebsiteConfig copyWith({
    String? status,
    String? templateId,
    String? themeColor,
    String? fontPair,
    String? coverImageUrl,
    String? heroImageUrl,
    Map<String, bool>? sections,
    String? publicUrl,
    String? publishedAt,
  }) {
    return EventWebsiteConfig(
      eventId: eventId,
      eventTitle: eventTitle,
      status: status ?? this.status,
      templateId: templateId ?? this.templateId,
      publicSlug: publicSlug,
      publicUrl: publicUrl ?? this.publicUrl,
      themeColor: themeColor ?? this.themeColor,
      fontPair: fontPair ?? this.fontPair,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      sections: sections ?? this.sections,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toPatchBody() => {
        if (templateId.isNotEmpty) 'templateId': templateId,
        'themeColor': themeColor,
        'fontPair': fontPair,
        'coverImageUrl': coverImageUrl,
        'heroImageUrl': heroImageUrl,
        'sections': sections,
      };
}

abstract final class EventWebsiteSectionKeys {
  static const ourStory = 'our_story';
  static const eventDetails = 'event_details';
  static const gallery = 'gallery';
  static const rsvp = 'rsvp';
  static const registry = 'registry';
  static const directions = 'directions';
  static const accommodation = 'accommodation';
  static const vendors = 'vendors';

  static const all = [
    ourStory,
    eventDetails,
    gallery,
    rsvp,
    registry,
    directions,
    accommodation,
    vendors,
  ];

  static const labels = {
    ourStory: 'Our Story',
    eventDetails: 'Event Details',
    gallery: 'Gallery',
    rsvp: 'RSVP',
    registry: 'Registry',
    directions: 'Directions',
    accommodation: 'Accommodation',
    vendors: 'Vendors',
  };

  static const defaults = {
    ourStory: true,
    eventDetails: true,
    gallery: true,
    rsvp: true,
    registry: false,
    directions: true,
    accommodation: false,
    vendors: false,
  };
}

class EventWebsiteTemplate {
  const EventWebsiteTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final String accentColor;
  final String icon;

  static const gallery = [
    EventWebsiteTemplate(
      id: 'wedding_classic',
      label: 'Wedding Classic',
      description: 'Elegant serif hero, ivory & plum palette',
      accentColor: '#4B2C6F',
      icon: '💍',
    ),
    EventWebsiteTemplate(
      id: 'traditional_wedding',
      label: 'Traditional Wedding',
      description: 'Rich gold accents, cultural celebration tone',
      accentColor: '#8B4513',
      icon: '🎊',
    ),
    EventWebsiteTemplate(
      id: 'birthday_celebration',
      label: 'Birthday Celebration',
      description: 'Vibrant, playful layout for milestones',
      accentColor: '#D97706',
      icon: '🎂',
    ),
    EventWebsiteTemplate(
      id: 'corporate_event',
      label: 'Corporate Event',
      description: 'Clean grid, professional typography',
      accentColor: '#2563EB',
      icon: '🏢',
    ),
    EventWebsiteTemplate(
      id: 'naming_ceremony',
      label: 'Naming Ceremony',
      description: 'Soft pastels, family-focused sections',
      accentColor: '#0D9488',
      icon: '👶',
    ),
  ];
}

abstract final class EventWebsiteFontPairs {
  static const options = [
    ('playfair_lato', 'Playfair + Lato'),
    ('cormorant_inter', 'Cormorant + Inter'),
    ('merriweather_opensans', 'Merriweather + Open Sans'),
    ('libre_baskerville_source', 'Libre Baskerville + Source Sans'),
    ('dm_serif_pro', 'DM Serif + DM Sans'),
  ];
}

abstract final class EventWebsiteThemeColors {
  static const presets = [
    '#4B2C6F',
    '#8B4513',
    '#D97706',
    '#2563EB',
    '#0D9488',
    '#DC2626',
    '#111827',
  ];
}
