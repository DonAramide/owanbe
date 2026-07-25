/// Shared profile infrastructure for Global, Attendee, Organizer, and Vendor profiles.
///
/// Profiles remain independent models. This package only provides reusable
/// layout, form widgets, validation, avatar upload, and save behaviour.
library;

export 'controllers/profile_edit_controller.dart';
export 'models/profile_avatar_value.dart';
export 'models/profile_social_link_defs.dart';
export 'repository/global_profile_repository.dart';
export 'repository/profile_media_uploader.dart';
export 'repository/profile_repository.dart';
export 'validation/profile_validators.dart';
export 'widgets/profile_avatar_editor.dart';
export 'widgets/profile_chip_selector.dart';
export 'widgets/profile_edit_layout.dart';
export 'widgets/profile_network_avatar.dart';
export 'widgets/profile_social_links_form.dart';
export 'widgets/profile_text_area.dart';
export 'widgets/profile_text_field.dart';
export 'widgets/profile_validation_message.dart';
