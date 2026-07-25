import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/public_models.dart';

/// Platform helpers for Event Details actions (share / calendar / maps / contact).
class EventDetailActions {
  static Future<void> shareEvent(PublicEvent event, {required String deepLink}) async {
    final text = '${event.title}\n${event.venue} · ${event.city}\n$deepLink';
    await SharePlus.instance.share(ShareParams(text: text, subject: event.title));
  }

  static Future<void> addToCalendar(PublicEvent event) async {
    final start = event.startsAt.toUtc();
    final end = event.endsAt.toUtc();
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}T'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}Z';

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Owanbe//Event Details//EN',
      'BEGIN:VEVENT',
      'UID:${event.id}@owanbe',
      'DTSTAMP:${fmt(DateTime.now().toUtc())}',
      'DTSTART:${fmt(start)}',
      'DTEND:${fmt(end)}',
      'SUMMARY:${_escape(event.title)}',
      'DESCRIPTION:${_escape(event.description)}',
      'LOCATION:${_escape('${event.venue}, ${event.city}')}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    final uri = Uri.dataFromString(ics, mimeType: 'text/calendar');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    // Fallback: Google Calendar template URL
    final gcal = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates': '${fmt(start)}/${fmt(end)}',
      'details': event.description,
      'location': '${event.venue}, ${event.city}',
    });
    await launchUrl(gcal, mode: LaunchMode.externalApplication);
  }

  static Future<void> openDirections(PublicEvent event) async {
    final lat = event.venueLatitude;
    final lng = event.venueLongitude;
    final query = Uri.encodeComponent(
      (event.venueAddress?.trim().isNotEmpty ?? false)
          ? event.venueAddress!.trim()
          : '${event.venue}, ${event.city}',
    );

    final candidates = <Uri>[
      if (lat != null && lng != null) Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(event.venue)})'),
      if (lat != null && lng != null)
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      Uri.parse('https://maps.apple.com/?q=$query'),
    ];

    for (final uri in candidates) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  static Future<void> openMapPreview(PublicEvent event) async {
    final lat = event.venueLatitude;
    final lng = event.venueLongitude;
    if (lat != null && lng != null) {
      final uri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    await openDirections(event);
  }

  static String staticMapUrl(PublicEvent event, {int width = 640, int height = 280}) {
    final lat = event.venueLatitude ?? 6.5244;
    final lng = event.venueLongitude ?? 3.3792;
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng&zoom=15&size=${width}x$height&markers=$lat,$lng,red-pushpin';
  }

  static Future<void> contactOrganizer({
    required String? email,
    required String? phone,
    required String eventTitle,
  }) async {
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      final uri = Uri(
        scheme: 'mailto',
        path: mail,
        queryParameters: {'subject': 'Regarding $eventTitle'},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }
    final tel = phone?.trim();
    if (tel != null && tel.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: tel);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }
    throw StateError('Organizer contact details are not available for this event.');
  }

  static String _escape(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll('\n', '\\n').replaceAll(',', '\\,').replaceAll(';', '\\;');
}
