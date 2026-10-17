import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'document_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _hasNavigated = true;
    super.dispose();
  }

  void _listenToAuthChanges() {
    AuthService().addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    if (_hasNavigated) return;
    final user = AuthService().currentUser;
    if (user != null && mounted) {
      _hasNavigated = true;
      _onLoggedIn(user);
    }
  }

  Future<void> _checkExistingSession() async {
    // Kiểm tra xem đã có session hợp lệ từ trước (initialSession)
    final user = AuthService().currentUser;
    if (user != null && mounted && !_hasNavigated) {
      _hasNavigated = true;
      _onLoggedIn(user);
    }
  }

  void _onLoggedIn(AppUser user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DocumentListScreen()),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
      // SDK tự xử lý OAuth redirect, onAuthStateChange listener sẽ cập nhật _currentUser
      // UI sẽ điều hướng khi listener fire sự kiện signedIn thông qua _onAuthStateChanged
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithTestUser(AppUser testUser) async {
    setState(() => _isLoading = true);
    final user = await AuthService().switchTestUser(testUser);
    if (mounted) {
      setState(() => _isLoading = false);
      _onLoggedIn(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon & Header
                  const Icon(
                    Icons.cloud_done_rounded,
                    size: 72,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QUẢN LÝ TÀI LIỆU HỌC TẬP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Supabase Storage + Supabase Auth + Row Level Security (RLS)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Nút Google Sign-In
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 22,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.account_circle,
                        color: Colors.redAccent,
                      ),
                    ),
                    label: const Text(
                      'Đăng nhập bằng tài khoản Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Đường phân cách
                  Row(
                    children: const [
                      Expanded(child: Divider(color: Color(0xFF334155))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'HOẶC KIỂM THỬ PHÂN QUYỀN (3 TÀI KHOẢN)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFF334155))),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3 Nút chọn tài khoản kiểm thử
                  _buildTestUserCard(
                    user: AuthService.demoUsers[0],
                    role: 'CHỦ SỞ HỮU (OWNER)',
                    color: const Color(0xFF10B981),
                    icon: Icons.admin_panel_settings_rounded,
                    description: 'Toàn quyền: Thêm, Xem, Sửa, Xóa và Chia sẻ tài liệu cho người khác',
                  ),
                  const SizedBox(height: 12),

                  _buildTestUserCard(
                    user: AuthService.demoUsers[1],
                    role: 'NGƯỜI CHỈ XEM (VIEWER)',
                    color: Colors.amber,
                    icon: Icons.visibility_rounded,
                    description: 'Chỉ được xem tài liệu được chia sẻ. RLS sẽ CHẶN nếu cố sửa hoặc xóa',
                  ),
                  const SizedBox(height: 12),

                  _buildTestUserCard(
                    user: AuthService.demoUsers[2],
                    role: 'NGƯỜI CHỈNH SỬA (EDITOR)',
                    color: Colors.lightBlueAccent,
                    icon: Icons.edit_note_rounded,
                    description: 'Được phép xem và sửa nội dung tài liệu được chia sẻ, nhưng KHÔNG được xóa',
                  ),

                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestUserCard({
    required AppUser user,
    required String role,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isLoading ? null : () => _loginWithTestUser(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                foregroundColor: color,
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          role,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}