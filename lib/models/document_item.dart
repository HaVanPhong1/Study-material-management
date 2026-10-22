class DocumentItem {
  final String id;
  final String ownerId;
  final String title;
  final String subject;
  final String docType;
  final String author;
  final int year;
  final String? storagePath;
  final String? fileUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String permissionLevel; // 'owner', 'edit', 'view'
  final List<String> tags;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;

  DocumentItem({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.subject,
    required this.docType,
    required this.author,
    required this.year,
    this.storagePath,
    this.fileUrl,
    required this.createdAt,
    required this.updatedAt,
    this.permissionLevel = 'owner',
    this.tags = const [],
    this.locationLabel,
    this.latitude,
    this.longitude,
  });

  String get docTypeLabel {
    switch (docType) {
      case 'bai_giang':
        return 'Bài giảng';
      case 'bai_tap':
        return 'Bài tập';
      case 'tai_lieu_tham_khao':
        return 'Tài liệu tham khảo';
      case 'de_thi':
        return 'Đề thi';
      default:
        return docType;
    }
  }

  bool get canEdit => permissionLevel == 'owner' || permissionLevel == 'edit';
  bool get isOwner => permissionLevel == 'owner';

  factory DocumentItem.fromMap(Map<String, dynamic> map, {String currentUserId = ''}) {
    final owner = map['owner_id']?.toString() ?? '';
    String perm = 'view';
    if (owner == currentUserId) {
      perm = 'owner';
    } else if (map['permission_level'] != null) {
      perm = map['permission_level'].toString();
    }

    return DocumentItem(
      id: map['id']?.toString() ?? '',
      ownerId: owner,
      title: map['title']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      docType: map['doc_type']?.toString() ?? 'bai_giang',
      author: map['author']?.toString() ?? '',
      year: int.tryParse(map['year']?.toString() ?? '2024') ?? 2024,
      storagePath: map['storage_path']?.toString(),
      fileUrl: map['file_url']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      permissionLevel: perm,
      tags: _readTags(map['tags']),
      locationLabel: map['location_label']?.toString(),
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
    );
  }

  static List<String> _readTags(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'subject': subject,
      'doc_type': docType,
      'author': author,
      'year': year,
      if (storagePath != null) 'storage_path': storagePath,
      if (fileUrl != null) 'file_url': fileUrl,
      'tags': tags,
      if (locationLabel != null) 'location_label': locationLabel,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Gợi ý tài liệu thông minh dựa trên:
/// - Trùng lặp Tag (trọng số cao: 2 điểm/tag)
/// - Trùng lặp Môn học (trọng số: 3 điểm)
/// - Trùng lặp Loại tài liệu (trọng số: 1 điểm)
/// Nếu người dùng chưa có tài liệu nào, gợi ý các tài liệu mới nhất hoặc phổ biến nhất.
List<DocumentItem> recommendDocuments(List<DocumentItem> all, String userId, {int limit = 3}) {
  final mine = all.where((d) => d.ownerId == userId).toList();
  final otherDocs = all.where((d) => d.ownerId != userId).toList();

  if (otherDocs.isEmpty) return [];

  // Nếu người dùng chưa đăng tải tài liệu nào, gợi ý các tài liệu mới nhất
  if (mine.isEmpty) {
    final sorted = List<DocumentItem>.from(otherDocs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  final userTags = mine.expand((d) => d.tags).map((t) => t.toLowerCase()).toSet();
  final userSubjects = mine.map((d) => d.subject.toLowerCase()).toSet();
  final userDocTypes = mine.map((d) => d.docType.toLowerCase()).toSet();

  final scored = <(DocumentItem, double)>[];

  for (final doc in otherDocs) {
    double score = 0.0;
    
    // Điểm tag (2 điểm cho mỗi tag trùng)
    for (final tag in doc.tags) {
      if (userTags.contains(tag.toLowerCase())) {
        score += 2.0;
      }
    }

    // Điểm môn học (3 điểm nếu trùng môn)
    if (userSubjects.contains(doc.subject.toLowerCase())) {
      score += 3.0;
    }

    // Điểm loại tài liệu (1 điểm nếu trùng loại)
    if (userDocTypes.contains(doc.docType.toLowerCase())) {
      score += 1.0;
    }

    if (score > 0) {
      scored.add((doc, score));
    }
  }

  // Sắp xếp theo điểm giảm dần
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  
  var results = scored.take(limit).map((e) => e.$1).toList();

  // Nếu không có tài liệu nào khớp điểm (>0), bổ sung tài liệu mới nhất
  if (results.isEmpty) {
    final sorted = List<DocumentItem>.from(otherDocs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    results = sorted.take(limit).toList();
  }

  return results;
}

List<String> parseTags(String raw) {
  return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
