import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/cloud_config.dart';
import '../models/permission_item.dart';
import 'auth_service.dart';
import 'document_service.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // --------------------------------------------------------------------------
  // LẤY DANH SÁCH QUYỀN ĐÃ CHIA SẺ CỦA TÀI LIỆU
  // --------------------------------------------------------------------------
  Future<List<PermissionItem>> getPermissions(String documentId) async {
    if (CloudConfig.isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('permissions')
            .select('id, document_id, user_id, permission_level, users(email, display_name)')
            .eq('document_id', documentId);

        return List<Map<String, dynamic>>.from(res)
            .map((m) => PermissionItem.fromMap(m))
            .toList();
      } catch (_) {}
    }

    // Mock permissions
    final permsMap = DocumentService().mockPermissions[documentId] ?? {};
    final users = AuthService.demoUsers;

    List<PermissionItem> result = [];
    permsMap.forEach((userId, level) {
      final user = users.firstWhere(
        (u) => u.id == userId,
        orElse: () => users[0],
      );
      result.add(PermissionItem(
        id: 'p_$userId',
        documentId: documentId,
        userId: userId,
        permissionLevel: level,
        userEmail: user.email,
        userDisplayName: user.displayName,
      ));
    });

    return result;
  }

  // --------------------------------------------------------------------------
  // CHIA SẺ TÀI LIỆU VỚI NGƯỜI DÙNG KHÁC BẰNG EMAIL
  // --------------------------------------------------------------------------
  Future<void> shareDocument({
    required String documentId,
    required String recipientEmail,
    required String permissionLevel, // 'view' or 'edit'
  }) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) throw Exception('Vui lòng đăng nhập.');

    final email = recipientEmail.trim().toLowerCase();
    if (email.isEmpty) throw Exception('Vui lòng nhập email người nhận.');

    if (email == currentUser.email.toLowerCase()) {
      throw Exception('Bạn là chủ sở hữu, không cần chia sẻ cho chính mình.');
    }

    if (CloudConfig.isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;

        // 1. Tìm user theo email
        final userRes = await client
            .from('users')
            .select('id')
            .eq('email', email)
            .maybeSingle();

        if (userRes == null) {
          throw Exception('Không tìm thấy tài khoản với email $email trên hệ thống.');
        }

        final recipientId = userRes['id'];

        // 2. Thêm hoặc cập nhật quyền vào bảng permissions
        await client.from('permissions').upsert({
          'document_id': documentId,
          'user_id': recipientId,
          'permission_level': permissionLevel,
        }, onConflict: 'document_id, user_id');

        return;
      } catch (e) {
        throw Exception('Lỗi chia sẻ: $e');
      }
    }

    // Mock share
    final users = AuthService.demoUsers;
    final foundUser = users.firstWhere(
      (u) => u.email.toLowerCase() == email,
      orElse: () => throw Exception('Không tìm thấy email $email (Trong chế độ kiểm thử, hãy dùng: userb_viewer@gmail.com hoặc userc_editor@gmail.com)'),
    );

    DocumentService().mockPermissions.putIfAbsent(documentId, () => {})[foundUser.id] = permissionLevel;
  }

  // --------------------------------------------------------------------------
  // THU HỒI QUYỀN CHIA SẺ
  // --------------------------------------------------------------------------
  Future<void> revokePermission(String documentId, String userId) async {
    if (CloudConfig.isSupabaseConfigured) {
      final client = Supabase.instance.client;
      await client
          .from('permissions')
          .delete()
          .eq('document_id', documentId)
          .eq('user_id', userId);
    }

    DocumentService().mockPermissions[documentId]?.remove(userId);
  }
}
