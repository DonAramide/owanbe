import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../features/public/models/attendee_event_models.dart';

/// Ticket pass actions — wallet-ready (payload retained); no Apple/Google Wallet yet.
abstract final class AttendeePassActions {
  static String passText(AttendeeEventView event) {
    return [
      'Owanbe Digital Pass',
      event.eventTitle,
      '${event.tierName} · ${event.venue}, ${event.city}',
      formatAttendeeDateRange(event.startsAt, event.endsAt),
      'Admission: ${event.liveStatusLabel}',
      if (event.accessLevel != null && event.accessLevel!.trim().isNotEmpty)
        'Access: ${event.accessLevel}',
      if (event.seatLabel != null && event.seatLabel!.trim().isNotEmpty)
        'Seat: ${event.seatLabel}',
      if (event.gateInfo != null && event.gateInfo!.trim().isNotEmpty)
        'Gate: ${event.gateInfo}',
      'Validation payload:',
      event.qrPayload,
    ].join('\n');
  }

  static Future<void> shareTicket(AttendeeEventView event) async {
    await SharePlus.instance.share(
      ShareParams(
        text: passText(event),
        subject: 'My ticket · ${event.eventTitle}',
      ),
    );
  }

  static Future<void> downloadTicket(BuildContext context, AttendeeEventView event) async {
    final text = passText(event);
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket details copied — paste to save offline')),
        );
      }
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/owanbe_pass_${event.ticket.id}.txt');
      await file.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Owanbe pass · ${event.eventTitle}',
          text: 'Your digital pass for ${event.eventTitle}',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket details copied to clipboard')),
        );
      }
    }
  }
}
