import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/cloud_config.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Supabase
  if (CloudConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        publishableKey: CloudConfig.supabasePublishableKey,
      );
      
      // Khởi tạo auth listener sau khi Supabase đã sẵn sàng
      AuthService().initializeAuthListener();
    } catch (e) {
      debugPrint('[Supabase Init] Lỗi kết nối Supabase: $e');
    }
  }

  runApp(const DocumentManagementApp());
}

class DocumentManagementApp extends StatelessWidget {
  const DocumentManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý Tài liệu Học tập',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0284C7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}