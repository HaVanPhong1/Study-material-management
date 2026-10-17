class CloudConfig {
  // Thay thế URL và Publishable Key lấy từ Supabase Project Settings -> API
  // Project URL: https://uisummjglhhedwvspawj.supabase.co
  static String supabaseUrl = 'https://uisummjglhhedwvspawj.supabase.co';
  static String supabasePublishableKey =
      'sb_publishable_QBGjZs5D4nQzSDJhrWmnLg_jBCdZw6j';

  // Cấu hình Google OAuth cho Supabase Auth
  // Lấy từ Google Cloud Console -> Credentials -> OAuth 2.0 Client IDs
  // Chỉ cần Client ID (KHÔNG cần Client Secret trong app)
  // Authorized redirect URI trong Google Cloud Console:
  // https://uisummjglhhedwvspawj.supabase.co/auth/v1/callback
  //
  // Supabase Dashboard -> Authentication -> Providers -> Google:
  // - Enable Google provider
  // - Paste Client ID và Client Secret từ Google Cloud Console
  // - Site URL: http://localhost:8080 (dev) hoặc production URL
  // - Redirect URLs: http://localhost:8080/** (dev)

  // Kiểm tra xem đã điền key thật chưa
  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.startsWith('sb_publishable_');
}
