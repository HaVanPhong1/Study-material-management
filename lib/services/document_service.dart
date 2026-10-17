import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/cloud_config.dart';
import '../models/document_item.dart';
export '../models/document_item.dart' show recommendDocuments, parseTags;
import 'auth_service.dart';

class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;
  DocumentService._internal();

  // Supabase Storage bucket name
  static const String _storageBucket = 'documents';

  // Dữ liệu mô phỏng đồng bộ với Seed Data trong scripts/supabase_schema_and_rls.sql
  final List<DocumentItem> _mockDocuments = [
    DocumentItem(
      id: 'd0000000-0000-0000-0000-000000000001',
      ownerId: 'a0000000-0000-0000-0000-000000000001',
      title: 'Bài giảng Giải tích 1 - Đạo hàm',
      subject: 'Toán cao cấp',
      docType: 'bai_giang',
      author: 'Nguyễn Văn A',
      year: 2024,
      storagePath: 'a0000000-0000-0000-0000-000000000001/d1/giai_tich_1.pdf',
      fileUrl: 'https://example.com/giai_tich_1.pdf',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      permissionLevel: 'owner',
      tags: const ['toan', 'dao-ham'],
      locationLabel: 'Thư viện A1, kệ 3',
      latitude: 21.0285,
      longitude: 105.8542,
    ),
    DocumentItem(
      id: 'd0000000-0000-0000-0000-000000000002',
      ownerId: 'a0000000-0000-0000-0000-000000000001',
      title: 'Đề thi cuối kỳ Lập trình Di động 2025',
      subject: 'Lập trình di động',
      docType: 'de_thi',
      author: 'Giảng viên Bộ môn',
      year: 2025,
      storagePath: 'a0000000-0000-0000-0000-000000000001/d2/de_thi_mobile.pdf',
      fileUrl: 'https://example.com/de_thi_mobile.pdf',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      permissionLevel: 'owner',
      tags: const ['mobile', 'de-thi'],
      locationLabel: 'Phòng bộ môn, tủ 2',
      latitude: 21.0278,
      longitude: 105.8342,
    ),
  ];

  // Danh sách quyền mô phỏng: doc1 được share cho B (view) và C (edit)
  final Map<String, Map<String, String>> _mockPermissions = {
    'd0000000-0000-0000-0000-000000000001': {
      'b0000000-0000-0000-0000-000000000002': 'view',
      'c0000000-0000-0000-0000-000000000003': 'edit',
    }
  };

  Map<String, Map<String, String>> get mockPermissions => _mockPermissions;

  // --------------------------------------------------------------------------
  // LẤY DANH SÁCH TÀI LIỆU (ÁP DỤNG RLS & BỘ LỌC)
  // --------------------------------------------------------------------------
  Future<List<DocumentItem>> getDocuments({
    String? keyword,
    String? docType,
    String? subject,
    int? yearFrom,
    int? yearTo,
  }) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return [];

    if (CloudConfig.isSupabaseConfigured) {
      final client = Supabase.instance.client;

      // Truy vấn Supabase: RLS sẽ tự động lọc chỉ tài liệu của Owner hoặc được chia sẻ
      var query = client.from('documents').select('*, permissions(*)');

      if (docType != null && docType.isNotEmpty) {
        query = query.eq('doc_type', docType);
      }
      if (subject != null && subject.isNotEmpty) {
        query = query.ilike('subject', '%$subject%');
      }
      if (yearFrom != null) {
        query = query.gte('year', yearFrom);
      }
      if (yearTo != null) {
        query = query.lte('year', yearTo);
      }

      final response = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(response);

      List<DocumentItem> results = [];
      for (final item in list) {
        String perm = 'view';
        if (item['owner_id'] == currentUser.id) {
          perm = 'owner';
        } else if (item['permissions'] != null && item['permissions'] is List) {
          for (final p in item['permissions']) {
            if (p['user_id'] == currentUser.id) {
              perm = p['permission_level'] ?? 'view';
              break;
            }
          }
        }

        final doc = DocumentItem.fromMap(item, currentUserId: currentUser.id);
        results.add(DocumentItem(
          id: doc.id,
          ownerId: doc.ownerId,
          title: doc.title,
          subject: doc.subject,
          docType: doc.docType,
          author: doc.author,
          year: doc.year,
          storagePath: doc.storagePath,
          fileUrl: doc.fileUrl,
          createdAt: doc.createdAt,
          updatedAt: doc.updatedAt,
          permissionLevel: perm,
          tags: doc.tags,
          locationLabel: doc.locationLabel,
          latitude: doc.latitude,
          longitude: doc.longitude,
        ));
      }

      // Lọc từ khóa theo title hoặc author
      if (keyword != null && keyword.trim().isNotEmpty) {
        final kw = keyword.trim().toLowerCase();
        results = results.where((d) =>
            d.title.toLowerCase().contains(kw) ||
            d.author.toLowerCase().contains(kw) ||
            d.subject.toLowerCase().contains(kw)).toList();
      }
      return results;
    }

    // --- MÔ PHỎNG THEO ĐÚNG RLS (Offline / Demo) ---
    List<DocumentItem> visible = [];
    for (final doc in _mockDocuments) {
      if (doc.ownerId == currentUser.id) {
        visible.add(DocumentItem(
          id: doc.id,
          ownerId: doc.ownerId,
          title: doc.title,
          subject: doc.subject,
          docType: doc.docType,
          author: doc.author,
          year: doc.year,
          storagePath: doc.storagePath,
          fileUrl: doc.fileUrl,
          createdAt: doc.createdAt,
          updatedAt: doc.updatedAt,
          permissionLevel: 'owner',
          tags: doc.tags,
          locationLabel: doc.locationLabel,
          latitude: doc.latitude,
          longitude: doc.longitude,
        ));
      } else if (_mockPermissions[doc.id]?.containsKey(currentUser.id) == true) {
        final perm = _mockPermissions[doc.id]![currentUser.id]!;
        visible.add(DocumentItem(
          id: doc.id,
          ownerId: doc.ownerId,
          title: doc.title,
          subject: doc.subject,
          docType: doc.docType,
          author: doc.author,
          year: doc.year,
          storagePath: doc.storagePath,
          fileUrl: doc.fileUrl,
          createdAt: doc.createdAt,
          updatedAt: doc.updatedAt,
          permissionLevel: perm,
          tags: doc.tags,
          locationLabel: doc.locationLabel,
          latitude: doc.latitude,
          longitude: doc.longitude,
        ));
      }
    }

    // Áp dụng bộ lọc
    if (keyword != null && keyword.trim().isNotEmpty) {
      final kw = keyword.trim().toLowerCase();
      visible = visible.where((d) =>
          d.title.toLowerCase().contains(kw) ||
          d.author.toLowerCase().contains(kw) ||
          d.subject.toLowerCase().contains(kw)).toList();
    }
    if (docType != null && docType.isNotEmpty) {
      visible = visible.where((d) => d.docType == docType).toList();
    }
    if (subject != null && subject.trim().isNotEmpty) {
      visible = visible.where((d) => d.subject.toLowerCase().contains(subject.trim().toLowerCase())).toList();
    }
    if (yearFrom != null) {
      visible = visible.where((d) => d.year >= yearFrom).toList();
    }
    if (yearTo != null) {
      visible = visible.where((d) => d.year <= yearTo).toList();
    }

    return visible;
  }

  // --------------------------------------------------------------------------
  // TẢI LÊN TÀI LIỆU MỚI (LƯU SUPABASE STORAGE + SUPABASE DB)
  // --------------------------------------------------------------------------
  Future<void> createDocument({
    required String title,
    required String subject,
    required String docType,
    required String author,
    required int year,
    Uint8List? fileBytes,
    String? fileName,
    List<String> tags = const [],
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) throw Exception('Vui lòng đăng nhập trước.');
    if (CloudConfig.isSupabaseConfigured &&
        Supabase.instance.client.auth.currentSession == null) {
      throw Exception(
        'Tài khoản demo không có phiên Supabase. Hãy đăng nhập Google để ghi dữ liệu.',
      );
    }

    final docId = const Uuid().v4();
    String? storagePath;
    String? fileUrl;

    // 1. Tải lên Supabase Storage nếu có file
    if (fileBytes != null && fileName != null) {
      // Tạo đường dẫn unique: documents/{supabase_user_id}/{docId}/{sanitized_filename}
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
      storagePath = '${currentUser.supabaseUserId}/$docId/$sanitizedFileName';

      if (CloudConfig.isSupabaseConfigured) {
        final client = Supabase.instance.client;
        
        // Upload file to Supabase Storage
        await client.storage.from(_storageBucket).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

        // Bucket là private: không dùng getPublicUrl vì sẽ không truy cập được.
        // Chỉ lưu storagePath ổn định và tạo Signed URL khi tải về.
        fileUrl = null;
      } else {
        // Mock mode: tạo URL mô phỏng
        fileUrl = 'https://mock-storage.example.com/$_storageBucket/$storagePath';
      }
    }

    // 2. Lưu metadata vào Supabase
    if (CloudConfig.isSupabaseConfigured) {
      final client = Supabase.instance.client;
      await client.from('documents').insert({
        'id': docId,
        'owner_id': currentUser.id,
        'title': title,
        'subject': subject,
        'doc_type': docType,
        'author': author,
        'year': year,
        'storage_path': storagePath,
        'file_url': fileUrl,
        'tags': tags,
        'location_label': locationLabel,
        'latitude': latitude,
        'longitude': longitude,
      });
      return;
    }

    // Cập nhật vào danh sách mô phỏng
    _mockDocuments.insert(
      0,
      DocumentItem(
        id: docId,
        ownerId: currentUser.id,
        title: title,
        subject: subject,
        docType: docType,
        author: author,
        year: year,
        storagePath: storagePath,
        fileUrl: fileUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        permissionLevel: 'owner',
        tags: tags,
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CẬP NHẬT TÀI LIỆU (Kiểm tra quyền Owner hoặc Editor)
  // --------------------------------------------------------------------------
  Future<void> updateDocument({
    required String documentId,
    required String title,
    required String subject,
    required String docType,
    required String author,
    required int year,
  }) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) throw Exception('Vui lòng đăng nhập.');

    // Kiểm tra quyền
    final docIndex = _mockDocuments.indexWhere((d) => d.id == documentId);
    if (docIndex != -1) {
      final target = _mockDocuments[docIndex];
      final isOwner = target.ownerId == currentUser.id;
      final isEditor = _mockPermissions[documentId]?[currentUser.id] == 'edit';

      if (!isOwner && !isEditor) {
        throw Exception('RLS Chặn: Bạn chỉ có quyền XEM (Viewer), không được chỉnh sửa tài liệu này!');
      }

      _mockDocuments[docIndex] = DocumentItem(
        id: target.id,
        ownerId: target.ownerId,
        title: title,
        subject: subject,
        docType: docType,
        author: author,
        year: year,
        storagePath: target.storagePath,
        fileUrl: target.fileUrl,
        createdAt: target.createdAt,
        updatedAt: DateTime.now(),
        permissionLevel: target.permissionLevel,
        tags: target.tags,
        locationLabel: target.locationLabel,
        latitude: target.latitude,
        longitude: target.longitude,
      );
    }

    if (CloudConfig.isSupabaseConfigured) {
      final client = Supabase.instance.client;
      await client.from('documents').update({
        'title': title,
        'subject': subject,
        'doc_type': docType,
        'author': author,
        'year': year,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', documentId);
    }
  }

  // --------------------------------------------------------------------------
  // XÓA TÀI LIỆU (Chỉ Owner)
  // --------------------------------------------------------------------------
  Future<void> deleteDocument(String documentId) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) throw Exception('Vui lòng đăng nhập.');

    String? storagePathToDelete;

    final docIndex = _mockDocuments.indexWhere((d) => d.id == documentId);
    if (docIndex != -1) {
      final target = _mockDocuments[docIndex];
      if (target.ownerId != currentUser.id) {
        throw Exception('RLS Chặn: Chỉ chủ sở hữu (Owner) mới có quyền XÓA tài liệu này!');
      }
      storagePathToDelete = target.storagePath;
      _mockDocuments.removeAt(docIndex);
      _mockPermissions.remove(documentId);
    }

    if (CloudConfig.isSupabaseConfigured) {
      final client = Supabase.instance.client;

      // Xóa file từ Supabase Storage nếu có
      if (storagePathToDelete != null && storagePathToDelete.isNotEmpty) {
        try {
          await client.storage.from(_storageBucket).remove([storagePathToDelete]);
        } catch (e) {
          // Log lỗi nhưng không throw để vẫn xóa được metadata
          developer.log('[Supabase Storage] Lỗi xóa file $storagePathToDelete: $e');
        }
      }

      // Xóa metadata từ database
      await client.from('documents').delete().eq('id', documentId);
    }
  }

  // --------------------------------------------------------------------------
  // LẤY SIGNED URL CHO DOWNLOAD (Bucket private)
  // --------------------------------------------------------------------------
  Future<String> getDownloadUrl(String storagePath) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) throw Exception('Vui lòng đăng nhập để tải tài liệu.');

    if (!CloudConfig.isSupabaseConfigured) {
      return 'https://mock-storage.example.com/$_storageBucket/$storagePath';
    }

    try {
      final client = Supabase.instance.client;
      // Tạo signed URL có hiệu lực 1 giờ (3600 giây)
      // Supabase Storage RLS sẽ kiểm tra xem currentUser có quyền SELECT không
      final signedUrl = await client.storage
          .from(_storageBucket)
          .createSignedUrl(storagePath, 3600);
      return signedUrl;
    } catch (e) {
      throw Exception('Không thể tạo liên kết tải file (RLS chặn hoặc file không tồn tại): $e');
    }
  }

  /// Gợi ý từ danh sách đang thấy: cùng tag hoặc cùng môn, không phải của mình.
  Future<List<DocumentItem>> recommendations() async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return [];
    final all = await getDocuments();
    return recommendDocuments(all, currentUser.id);
  }

  /// Yêu cầu mượn bản giấy. Chủ tài liệu duyệt trong cùng bảng.
  Future<void> requestBorrow(String documentId) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) throw Exception('Vui lòng đăng nhập.');
    if (!CloudConfig.isSupabaseConfigured) {
      throw Exception('Chế độ demo chưa lưu yêu cầu mượn. Cần Supabase.');
    }
    await Supabase.instance.client.from('borrow_requests').insert({
      'document_id': documentId,
      'requester_id': currentUser.id,
      'status': 'pending',
    });
  }
}