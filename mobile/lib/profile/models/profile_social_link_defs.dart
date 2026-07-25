/// Canonical social link fields used by profile editors.
class ProfileSocialLinkDef {
  const ProfileSocialLinkDef({
    required this.key,
    required this.label,
    required this.hint,
  });

  final String key;
  final String label;
  final String hint;
}

const kDefaultProfileSocialLinkDefs = <ProfileSocialLinkDef>[
  ProfileSocialLinkDef(key: 'instagram', label: 'Instagram', hint: 'https://instagram.com/...'),
  ProfileSocialLinkDef(key: 'twitter', label: 'X / Twitter', hint: 'https://x.com/...'),
  ProfileSocialLinkDef(key: 'linkedin', label: 'LinkedIn', hint: 'https://linkedin.com/in/...'),
  ProfileSocialLinkDef(key: 'facebook', label: 'Facebook', hint: 'https://facebook.com/...'),
  ProfileSocialLinkDef(key: 'tiktok', label: 'TikTok', hint: 'https://tiktok.com/@...'),
  ProfileSocialLinkDef(key: 'youtube', label: 'YouTube', hint: 'https://youtube.com/@...'),
  ProfileSocialLinkDef(key: 'website', label: 'Website', hint: 'https://...'),
];
