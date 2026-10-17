import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/cloud_config.dart';
import '../models/app_user.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  // 3 tài khoản mặc định để kiểm thử phân quyền (RLS Testing)
  static final List<AppUser> demoUsers = [
    AppUser(
      id: 'a0000000-0000-0000-0000-000000000001',
      supabaseUserId: 'a0000000-0000-0000-0000-000000000001',
      email: 'usera_owner@gmail.com',
      displayName: 'User A (Chủ sở hữu - Owner)',
    ),
    AppUser(
      id: 'b0000000-0000-0000-0000-000000000002',
      supabaseUserId: 'b0000000-0000-0000-0000-000000000002',
      email: 'userb_viewer@gmail.com',
      displayName: 'User B (Người chỉ xem - Viewer)',
    ),
    AppUser(
      id: 'c0000000-0000-0000-0000-000000000003',
      supabaseUserId: 'c0000000-0000-0000-0000-000000000003',
      email: 'userc_editor@gmail.com',
      displayName: 'User C (Người chỉnh sửa - Editor)',
    ),
  ];

  // Khởi tạo listener cho thay đổi trạng thái auth
  void initializeAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.initialSession && session != null) {
        _handleUserSignedIn(session.user);
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        _handleUserSignedIn(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        notifyListeners();
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        _handleUserSignedIn(session.user);
      }
    });

    // Khôi phục phiên đăng nhập khi mở app
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await _handleUserSignedIn(session.user);
      }
    } catch (e) {
      debugPrint('[Auth] Lỗi khôi phục phiên: $e');
    }
  }

  Future<void> _handleUserSignedIn(User supabaseUser) async {
    if (!CloudConfig.isSupabaseConfigured) return;

    final userMetadata = supabaseUser.userMetadata;
    final fullName = userMetadata?['full_name']?.toString();
    final avatarUrl = userMetadata?['avatar_url']?.toString();
    final email = supabaseUser.email ?? '';

    try {
      final client = Supabase.instance.client;

      // Lấy hoặc tạo user trong bảng users
      final res = await client.from('users').upsert({
        'supabase_user_id': supabaseUser.id,
        'email': email,
        'display_name': fullName ?? email.split('@').first,
        'photo_url': avatarUrl,
      }, onConflict: 'supabase_user_id').select('id').single();

      final profileId = res['id']?.toString();
      if (profileId == null || profileId.isEmpty) {
        throw Exception('Bảng users không trả về id hồ sơ.');
      }

      _currentUser = AppUser(
        id: profileId,
        supabaseUserId: supabaseUser.id,
        email: email,
        displayName: fullName ?? email.split('@').first,
        photoUrl: avatarUrl,
      );
    } catch (e) {
      debugPrint('[Auth] Lỗi đồng bộ user: $e');
      // Không dùng auth.uid() làm users.id: policy INSERT documents sẽ từ chối.
      _currentUser = null;
    }
    notifyListeners();
  }

  // Đăng nhập nhanh bằng 1 trong 3 tài khoản kiểm thử
  Future<AppUser> switchTestUser(AppUser testUser) async {
    _currentUser = testUser;
    notifyListeners();

    if (CloudConfig.isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client.from('users').upsert({
          'id': testUser.id,
          'supabase_user_id': testUser.supabaseUserId,
          'email': testUser.email,
          'display_name': testUser.displayName,
        }, onConflict: 'email');
      } catch (e) {
        // Ignored in test/offline mode
      }
    }
    return testUser;
  }

  // Đăng nhập bằng Google qua Supabase Auth (OAuth)
  Future<void> signInWithGoogle() async {
    if (!CloudConfig.isSupabaseConfigured) {
      throw Exception(
        'Chưa cấu hình Supabase. Vui lòng điền Publishable Key trong lib/config/cloud_config.dart '
        'và cấu hình Google OAuth trong Supabase Dashboard.\n'
        '👉 Hiện tại, bạn hãy bấm vào 1 trong 3 tài khoản Demo bên dưới để kiểm thử ngay!'
      );
    }

    final client = Supabase.instance.client;

    // SDK tự xử lý redirect URL trên Web (window.origin) và deep link trên mobile
    await client.auth.signInWithOAuth(OAuthProvider.google);

    // Không return user ngay - onAuthStateChange listener sẽ xử lý khi session sẵn sàng
  }

  // Xử lý callback sau OAuth redirect (gọi từ main.dart sau khi init)
  Future<AppUser?> handleAuthCallback() async {
    if (!CloudConfig.isSupabaseConfigured) return null;
    // SDK đã xử lý callback qua onAuthStateChange, chỉ trả về user hiện tại
    return _currentUser;
  }

  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}