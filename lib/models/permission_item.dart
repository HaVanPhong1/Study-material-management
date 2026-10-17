class PermissionItem {
  final String id;
  final String documentId;
  final String userId;
  final String permissionLevel; // 'view' or 'edit'
  final String? userEmail;
  final String? userDisplayName;

  PermissionItem({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.permissionLevel,
    this.userEmail,
    this.userDisplayName,
  });

  String get permissionLabel => permissionLevel == 'edit' ? 'Được chỉnh sửa' : 'Chỉ xem';

  factory PermissionItem.fromMap(Map<String, dynamic> map) {
    String? email;
    String? name;
    if (map['users'] != null && map['users'] is Map) {
      email = map['users']['email']?.toString();
      name = map['users']['display_name']?.toString();
    }

    return PermissionItem(
      id: map['id']?.toString() ?? '',
      documentId: map['document_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      permissionLevel: map['permission_level']?.toString() ?? 'view',
      userEmail: email ?? map['user_email']?.toString(),
      userDisplayName: name,
    );
  }
}
