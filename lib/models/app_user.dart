class AppUser {
  final String id;
  final String supabaseUserId;
  final String email;
  final String displayName;
  final String? photoUrl;

  AppUser({
    required this.id,
    required this.supabaseUserId,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      supabaseUserId: map['supabase_user_id']?.toString() ?? map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? map['email']?.toString() ?? 'Người dùng',
      photoUrl: map['photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supabase_user_id': supabaseUserId,
      'email': email,
      'display_name': displayName,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }
}