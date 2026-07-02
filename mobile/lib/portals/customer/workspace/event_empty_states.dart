import 'package:flutter/material.dart';

import 'widgets/event_empty_state.dart';

/// Preset empty states for Event OS modules (Phase 42.4 / 42.6).
abstract final class EventEmptyStates {
  static Widget guests({
    required VoidCallback onAdd,
    VoidCallback? onImport,
  }) {
    return EventEmptyState(
      title: 'No guests yet',
      description: 'Start building your guest list for invitations and check-in.',
      icon: Icons.groups_outlined,
      primaryActionLabel: 'Add guest',
      onPrimaryAction: onAdd,
      secondaryActionLabel: onImport != null ? 'Import contacts' : null,
      onSecondaryAction: onImport,
    );
  }

  static Widget guestsFiltered({required VoidCallback onAdd}) {
    return EventEmptyState(
      title: 'No guests match',
      description: 'Try a different search or filter, or add guests to your celebration.',
      icon: Icons.search_off_outlined,
      primaryActionLabel: 'Add guest',
      onPrimaryAction: onAdd,
    );
  }

  static Widget vendors({required VoidCallback onBrowse}) {
    return EventEmptyState(
      title: 'No vendors requested',
      description: 'Browse the marketplace to request caterers, DJs, photographers, and more.',
      icon: Icons.handshake_outlined,
      primaryActionLabel: 'Browse marketplace',
      onPrimaryAction: onBrowse,
    );
  }

  static Widget invitations({required VoidCallback onCreate}) {
    return EventEmptyState(
      title: 'No invitations sent',
      description: 'Design beautiful invitation cards and share them with your guests.',
      icon: Icons.mail_outline,
      primaryActionLabel: 'Create invitation',
      onPrimaryAction: onCreate,
    );
  }

  static Widget program({required VoidCallback onAdd}) {
    return EventEmptyState(
      title: 'No program created',
      description: 'Build your run sheet with timelines, owners, and day-of status.',
      icon: Icons.schedule_outlined,
      primaryActionLabel: 'Add program item',
      onPrimaryAction: onAdd,
    );
  }

  static Widget budget() {
    return const EventEmptyState(
      title: 'Budget not configured',
      description: 'Set your celebration budget to track spend and vendor commitments.',
      icon: Icons.account_balance_wallet_outlined,
    );
  }

  static Widget rentals({required VoidCallback onBrowse}) {
    return EventEmptyState(
      title: 'No rentals booked',
      description: 'Browse chairs, tents, sound, and lighting from trusted rental partners.',
      icon: Icons.inventory_2_outlined,
      primaryActionLabel: 'Browse rentals',
      onPrimaryAction: onBrowse,
    );
  }

  static Widget website({required VoidCallback onEdit}) {
    return EventEmptyState(
      title: 'Website not published',
      description: 'Create a beautiful microsite for your celebration details and RSVP.',
      icon: Icons.language_outlined,
      primaryActionLabel: 'Open website builder',
      onPrimaryAction: onEdit,
    );
  }

  static Widget wall({VoidCallback? onPost}) {
    return EventEmptyState(
      title: 'No messages yet',
      description: 'Be the first to congratulate the hosts on the celebration wall.',
      icon: Icons.forum_outlined,
      primaryActionLabel: onPost != null ? 'Add message' : null,
      onPrimaryAction: onPost,
    );
  }

  static Widget seating({required VoidCallback onAddTable}) {
    return EventEmptyState(
      title: 'No seating layout',
      description: 'Add tables and assign guests for a clear seating layout.',
      icon: Icons.table_restaurant_outlined,
      primaryActionLabel: 'Add table',
      onPrimaryAction: onAddTable,
    );
  }

  static Widget media({required VoidCallback onUpload}) {
    return EventEmptyState(
      title: 'No media uploaded',
      description: 'Add photos and videos to share memories from your celebration.',
      icon: Icons.photo_library_outlined,
      primaryActionLabel: 'Upload media',
      onPrimaryAction: onUpload,
    );
  }

  static Widget attirePackages({required VoidCallback onAdd}) {
    return EventEmptyState(
      title: 'No packages yet',
      description: 'Create fabric packages for guests to reserve attire for your celebration.',
      icon: Icons.checkroom_outlined,
      primaryActionLabel: 'Add package',
      onPrimaryAction: onAdd,
    );
  }

  static Widget attireOrders() {
    return const EventEmptyState(
      title: 'No orders yet',
      description: 'Guest reservations and pickup status will appear here.',
      icon: Icons.shopping_bag_outlined,
    );
  }

  static Widget attireVendors({required VoidCallback onBrowse}) {
    return EventEmptyState(
      title: 'No fashion vendors',
      description: 'Browse fashion and attire partners for your celebration.',
      icon: Icons.storefront_outlined,
      primaryActionLabel: 'Browse vendors',
      onPrimaryAction: onBrowse,
    );
  }

  static Widget activity() {
    return const EventEmptyState(
      title: 'No activity yet',
      description: 'Updates from guests, vendors, and planning will appear here.',
      icon: Icons.timeline_outlined,
    );
  }
}
