import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/organizer_models.dart';
import '../../../shared/models/event_access_mode.dart';

const _kLocalDraftKey = 'owanbe_event_wizard_v2_local_draft';

/// Envelope restored after refresh / resume (draft + server linkage + step).
class WizardLocalSnapshot {
  const WizardLocalSnapshot({
    required this.draft,
    this.serverEventId,
    this.wizardStep = 0,
    this.dirty = false,
  });

  final EventWizardV2Draft draft;
  final String? serverEventId;
  final int wizardStep;
  final bool dirty;
}

/// In-progress wizard autosave (local) + optional server event id for PATCH.
class WizardAutosaveState {
  const WizardAutosaveState({
    this.serverEventId,
    this.wizardStep = 0,
    this.dirty = false,
    this.lastSavedAt,
    this.draftJson,
  });

  final String? serverEventId;
  final int wizardStep;
  final bool dirty;
  final DateTime? lastSavedAt;
  final Map<String, dynamic>? draftJson;

  WizardAutosaveState copyWith({
    String? serverEventId,
    int? wizardStep,
    bool? dirty,
    DateTime? lastSavedAt,
    Map<String, dynamic>? draftJson,
    bool clearServerId = false,
  }) {
    return WizardAutosaveState(
      serverEventId: clearServerId ? null : (serverEventId ?? this.serverEventId),
      wizardStep: wizardStep ?? this.wizardStep,
      dirty: dirty ?? this.dirty,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      draftJson: draftJson ?? this.draftJson,
    );
  }
}

final wizardAutosaveProvider = NotifierProvider<WizardAutosaveController, WizardAutosaveState>(
  WizardAutosaveController.new,
);

class WizardAutosaveController extends Notifier<WizardAutosaveState> {
  Timer? _debounce;

  @override
  WizardAutosaveState build() => const WizardAutosaveState();

  void markDirty() {
    state = state.copyWith(dirty: true);
  }

  void bindServerEvent(String eventId) {
    state = state.copyWith(serverEventId: eventId, dirty: false, lastSavedAt: DateTime.now());
  }

  void setWizardStep(int step) {
    state = state.copyWith(wizardStep: step);
  }

  void clear() {
    _debounce?.cancel();
    state = const WizardAutosaveState();
    SharedPreferences.getInstance().then((p) => p.remove(_kLocalDraftKey));
  }

  Future<void> persistLocal(
    EventWizardV2Draft draft, {
    String? serverEventId,
    int? wizardStep,
  }) async {
    final sid = serverEventId ?? state.serverEventId;
    final step = wizardStep ?? state.wizardStep;
    final envelope = <String, dynamic>{
      'v': 2,
      'serverEventId': sid,
      'wizardStep': step,
      'dirty': true,
      'draft': draftToJson(draft),
    };
    state = state.copyWith(
      dirty: true,
      draftJson: envelope,
      serverEventId: sid,
      wizardStep: step,
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final prefs = await SharedPreferences.getInstance();
      envelope['dirty'] = false;
      await prefs.setString(_kLocalDraftKey, jsonEncode(envelope));
      state = state.copyWith(
        dirty: false,
        lastSavedAt: DateTime.now(),
        draftJson: envelope,
        serverEventId: sid,
        wizardStep: step,
      );
    });
  }

  Future<WizardLocalSnapshot?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalDraftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // v2 envelope
      if (map['draft'] is Map) {
        final draftMap = Map<String, dynamic>.from(map['draft'] as Map);
        final draft = draftFromJson(draftMap);
        final sid = map['serverEventId']?.toString();
        final step = (map['wizardStep'] as num?)?.toInt() ?? 0;
        final dirty = map['dirty'] == true;
        state = state.copyWith(
          draftJson: map,
          dirty: dirty,
          serverEventId: sid,
          wizardStep: step,
          clearServerId: sid == null || sid.isEmpty,
        );
        return WizardLocalSnapshot(
          draft: draft,
          serverEventId: (sid != null && sid.isNotEmpty) ? sid : null,
          wizardStep: step,
          dirty: dirty,
        );
      }
      // Legacy flat draft JSON (pre-H2)
      final draft = draftFromJson(map);
      state = state.copyWith(draftJson: map, dirty: false, clearServerId: true);
      return WizardLocalSnapshot(draft: draft);
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> draftToJson(EventWizardV2Draft d) => {
      'categorySlug': d.categorySlug,
      'categoryLabel': d.categoryLabel,
      'eventAccessMode': d.eventAccessMode.apiValue,
      'title': d.title,
      'tagline': d.tagline,
      'description': d.description,
      'city': d.city,
      'venueName': d.venueName,
      'venueAddress': d.venueAddress,
      'venueLatitude': d.venueLatitude,
      'venueLongitude': d.venueLongitude,
      'googlePlaceId': d.googlePlaceId,
      'budgetMinor': d.budgetMinor,
      'expectedGuests': d.expectedGuests,
      'tags': d.tags,
      'budgetAllocation': d.budgetAllocation,
      'startsAt': d.startsAt.toIso8601String(),
      'endsAt': d.endsAt.toIso8601String(),
      'requiredServices': d.requiredServices,
      'venueDeferred': d.venueDeferred,
      'state': d.state,
      'lga': d.lga,
      'celebrantImageUrl': d.celebrantImageUrl,
      'language': d.language,
      'ageRestrictionMin': d.ageRestrictionMin,
      'listingVisibility': d.listingVisibility,
      'venueType': d.venueType.name,
      'registrationEnabled': d.registrationEnabled,
      'checkInEnabled': d.checkInEnabled,
      'bannerLabel': d.bannerLabel,
      'themeColor': d.themeColor,
      'selectedTemplateSlug': d.selectedTemplateSlug,
      'ticketTiers': d.ticketTiers
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'description': t.description,
                'priceMinor': t.priceMinor,
                'currency': t.currency,
                'capacity': t.capacity,
                'remaining': t.remaining,
                'tierType': t.tierType.name,
                'visibility': t.visibility.name,
              })
          .toList(),
    };

EventWizardV2Draft draftFromJson(Map<String, dynamic> m) {
  final tiers = (m['ticketTiers'] as List<dynamic>? ?? [])
      .map((e) {
        final t = e as Map<String, dynamic>;
        return OrganizerTicketTier(
          id: (t['id'] ?? '').toString(),
          name: (t['name'] ?? '').toString(),
          description: (t['description'] ?? '').toString(),
          priceMinor: (t['priceMinor'] as num?)?.toInt() ?? 0,
          currency: (t['currency'] ?? 'NGN').toString(),
          capacity: (t['capacity'] as num?)?.toInt() ?? 0,
          remaining: (t['remaining'] as num?)?.toInt() ?? 0,
          tierType: TicketTierType.values.firstWhere(
            (v) => v.name == t['tierType'],
            orElse: () => TicketTierType.regular,
          ),
          visibility: t['visibility'] == 'hidden' ? TicketVisibility.hidden : TicketVisibility.publicListing,
        );
      })
      .toList();

  return EventWizardV2Draft(
    categorySlug: (m['categorySlug'] ?? '').toString(),
    categoryLabel: (m['categoryLabel'] ?? '').toString(),
    eventAccessMode: EventAccessModeX.fromApi((m['eventAccessMode'] ?? 'PRIVATE_INVITATION').toString()),
    title: (m['title'] ?? '').toString(),
    tagline: (m['tagline'] ?? '').toString(),
    description: (m['description'] ?? '').toString(),
    city: (m['city'] ?? '').toString(),
    venueName: (m['venueName'] ?? '').toString(),
    venueAddress: (m['venueAddress'] ?? '').toString(),
    venueLatitude: (m['venueLatitude'] as num?)?.toDouble(),
    venueLongitude: (m['venueLongitude'] as num?)?.toDouble(),
    googlePlaceId: m['googlePlaceId']?.toString(),
    budgetMinor: (m['budgetMinor'] as num?)?.toInt() ?? 0,
    expectedGuests: (m['expectedGuests'] as num?)?.toInt() ?? 150,
    tags: (m['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    budgetAllocation: (m['budgetAllocation'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    startsAt: DateTime.tryParse((m['startsAt'] ?? '').toString()),
    endsAt: DateTime.tryParse((m['endsAt'] ?? '').toString()),
    ticketTiers: tiers,
    requiredServices: (m['requiredServices'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    venueDeferred: m['venueDeferred'] == true,
    state: (m['state'] ?? '').toString(),
    lga: (m['lga'] ?? '').toString(),
    celebrantImageUrl: m['celebrantImageUrl']?.toString(),
    language: (m['language'] ?? 'en').toString(),
    ageRestrictionMin: (m['ageRestrictionMin'] as num?)?.toInt() ?? 0,
    listingVisibility: (m['listingVisibility'] ?? 'invite_only').toString(),
    venueType: VenueType.values.firstWhere(
      (v) => v.name == m['venueType'],
      orElse: () => VenueType.physical,
    ),
    registrationEnabled: m['registrationEnabled'] != false,
    checkInEnabled: m['checkInEnabled'] != false,
    bannerLabel: (m['bannerLabel'] ?? 'Default banner').toString(),
    themeColor: (m['themeColor'] ?? '#4B2C6F').toString(),
    selectedTemplateSlug: (m['selectedTemplateSlug'] ?? '').toString(),
  );
}
