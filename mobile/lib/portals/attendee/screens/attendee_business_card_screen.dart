import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/networking_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../profile/widgets/profile_network_avatar.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_networking_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Digital business card — photo, contact, QR, share/save (Phase 8.4).
class AttendeeBusinessCardScreen extends ConsumerWidget {
  const AttendeeBusinessCardScreen({super.key, this.eventId});

  final String? eventId;

  Future<void> _share(BuildContext context, BusinessCard card) async {
    await SharePlus.instance.share(
      ShareParams(text: card.shareText, subject: '${card.displayName} · Business card'),
    );
  }

  Future<void> _saveContact(BuildContext context, BusinessCard card) async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: card.shareText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact details copied (web cannot write contacts)')),
        );
      }
      return;
    }
    try {
      final granted = await FlutterContacts.requestPermission(readonly: false);
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission is required to save')),
          );
        }
        return;
      }
      final contact = Contact()
        ..name = Name(first: card.displayName)
        ..organizations = [
          if (card.company != null || card.occupation != null)
            Organization(
              company: card.company ?? '',
              title: card.occupation ?? '',
            ),
        ]
        ..emails = [
          if (card.email != null && card.email!.isNotEmpty) Email(card.email!),
        ]
        ..phones = [
          if (card.phone != null && card.phone!.isNotEmpty) Phone(card.phone!),
        ]
        ..websites = [
          for (final e in card.socialLinks.entries)
            Website(e.value, label: WebsiteLabel.custom, customLabel: e.key),
        ];
      await FlutterContacts.insertContact(contact);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved')),
        );
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: card.shareText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save contact — copied instead ($e)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingBusinessCardProvider);
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Back',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else if (eventId != null) {
          context.go(AttendeeRoutes.people(eventId!));
        } else {
          context.go(AttendeeRoutes.dashboard);
        }
      },
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(networkingBusinessCardProvider);
          await ref.read(networkingBusinessCardProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: const [NetworkingListSkeleton(count: 2)],
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(headline: 'Business card unavailable', message: '$e', severity: 'CRITICAL'),
              TextButton(
                onPressed: () => ref.invalidate(networkingBusinessCardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (card) {
            if (card == null) {
              return ListView(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                children: [
                  EosSurfaceCard(
                    child: Text('Sign in to view your business card.', style: context.eosText.bodyMedium),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                Text('My business card', style: context.eosText.headlineMedium),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  'Share at the event. Contact fields follow your profile settings.',
                  style: context.eosText.bodySmall,
                ),
                if (offline) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  const EosAttentionBanner(
                    headline: 'Offline',
                    message: 'Card may be from the last successful load.',
                    severity: 'WARNING',
                  ),
                ],
                SizedBox(height: context.eos.spacing.lg),
                EosSurfaceCard(
                  elevated: true,
                  child: Column(
                    children: [
                      ProfileNetworkAvatar(
                        name: card.displayName,
                        avatarUrl: card.avatarUrl,
                        radius: 44,
                      ),
                      SizedBox(height: context.eos.spacing.md),
                      Text(card.displayName, style: context.eosText.headlineSmall),
                      if (card.occupation != null || card.company != null)
                        Text(
                          [card.occupation, card.company]
                              .whereType<String>()
                              .where((s) => s.trim().isNotEmpty)
                              .join(' · '),
                          style: context.eosText.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      if (card.email != null) ...[
                        SizedBox(height: context.eos.spacing.sm),
                        Text(card.email!, style: context.eosText.bodySmall),
                      ],
                      if (card.phone != null) Text(card.phone!, style: context.eosText.bodySmall),
                      if (card.socialLinks.isNotEmpty) ...[
                        SizedBox(height: context.eos.spacing.sm),
                        for (final e in card.socialLinks.entries)
                          Text('${e.key}: ${e.value}', style: context.eosText.bodySmall),
                      ],
                      SizedBox(height: context.eos.spacing.lg),
                      if (card.qrPayload.isNotEmpty)
                        QrImageView(
                          data: card.qrPayload,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                FilledButton.icon(
                  onPressed: () => _share(context, card),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share card'),
                ),
                SizedBox(height: context.eos.spacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _saveContact(context, card),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Save contact'),
                ),
                SizedBox(height: context.eos.spacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: card.shareText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Card text copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy details'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
