import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document_item.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import 'edit_document_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'share_screen.dart';
import 'upload_screen.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final _searchController = TextEditingController();
  String _selectedDocType = '';
  String? _selectedTag;
  List<DocumentItem> _documents = [];
  List<DocumentItem> _recommendations = [];
  bool _isLoading = true;
  String? _downloadingDocId;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await DocumentService().getDocuments(
        keyword: _searchController.text.trim(),
        docType: _selectedDocType.isEmpty ? null : _selectedDocType,
        tag: _selectedTag,
      );
      final recs = await DocumentService().recommendations();
      setState(() {
        _documents = docs;
        _recommendations = recs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải tài liệu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() {
    AuthService().signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _switchUserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Chuyển đổi tài khoản kiểm thử', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AuthService.demoUsers.map((u) {
            final isCurrent = u.id == AuthService().currentUser?.id;
            return ListTile(
              title: Text(u.displayName, style: TextStyle(color: isCurrent ? const Color(0xFF38BDF8) : Colors.white)),
              subtitle: Text(u.email, style: const TextStyle(color: Color(0xFF94A3B8))),
              trailing: isCurrent ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
              onTap: () async {
                Navigator.pop(ctx);
                await AuthService().switchTestUser(u);
                _loadDocuments();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _deleteDocument(DocumentItem doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xác nhận xóa tài liệu', style: TextStyle(color: Colors.white)),
        content: Text('Bạn có chắc chắn muốn xóa "${doc.title}"?', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DocumentService().deleteDocument(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tài liệu thành công.'), backgroundColor: Colors.green),
        );
        _loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('RLS BẢO MẬT CHẶN', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              ],
            ),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(DocumentItem doc) async {
    final path = doc.storagePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài liệu này không có tệp đính kèm trên Storage.')),
      );
      return;
    }

    setState(() => _downloadingDocId = doc.id);

    try {
      final signedUrl = await DocumentService().getDownloadUrl(path);
      final uri = Uri.parse(signedUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback mở trực tiếp
        await launchUrl(uri);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang mở liên kết tải file: ${doc.title}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('RLS STORAGE CHẶN', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              ],
            ),
            content: Text(
              'Không thể tải tệp tin đính kèm.\n'
              'Chỉ chủ sở hữu (Owner) hoặc người dùng được chia sẻ quyền (Viewer / Editor) mới được phép tải về.\n\n'
              'Chi tiết lỗi: $e',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFF38BDF8))),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingDocId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TÀI LIỆU HỌC TẬP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(
              '${user?.displayName} (${user?.email})',
              style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Xem bản đồ vị trí tài liệu',
            icon: const Icon(Icons.map_rounded, color: Color(0xFF10B981)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapScreen(
                    mode: MapScreenMode.viewDocuments,
                    documents: _documents,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Đổi tài khoản kiểm thử (RLS)',
            icon: const Icon(Icons.switch_account_rounded, color: Color(0xFF38BDF8)),
            onPressed: _switchUserDialog,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Khung tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tiêu đề, môn học, tác giả...',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _loadDocuments();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _loadDocuments(),
            ),
          ),

          // Bộ lọc loại tài liệu (Filter chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', ''),
                _buildFilterChip('Bài giảng', 'bai_giang'),
                _buildFilterChip('Bài tập', 'bai_tap'),
                _buildFilterChip('Tài liệu tham khảo', 'tai_lieu_tham_khao'),
                _buildFilterChip('Đề thi', 'de_thi'),
              ],
            ),
          ),

          // Bộ lọc Thẻ (Tag Filter Bar động từ các tài liệu đang có)
          _buildTagFilterBar(),

          if (_recommendations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: const [
                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Text(
                    'Gợi ý cho bạn (theo Tag & Môn học)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recommendations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final r = _recommendations[i];
                  return ActionChip(
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    avatar: const Icon(Icons.bookmark_border, size: 14, color: Color(0xFFF59E0B)),
                    label: Text(r.title, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    onPressed: () {
                      _searchController.text = r.title;
                      _loadDocuments();
                    },
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Danh sách tài liệu
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.folder_off_outlined, size: 64, color: Color(0xFF475569)),
                            const SizedBox(height: 12),
                            const Text('Không có tài liệu nào.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                            const SizedBox(height: 6),
                            Text(
                              user?.id == AuthService.demoUsers[0].id
                                  ? 'Bấm nút (+) bên dưới để thêm tài liệu mới.'
                                  : 'Tài khoản này chưa được ai chia sẻ tài liệu nào.',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDocuments,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            return _buildDocumentCard(doc);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        label: const Text('Tải tài liệu lên', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadScreen()),
          );
          if (res == true) _loadDocuments();
        },
      ),
    );
  }

  Widget _buildTagFilterBar() {
    // Thu thập danh sách tag duy nhất từ các tài liệu đang tải
    final allTags = <String>{};
    for (final doc in _documents) {
      allTags.addAll(doc.tags);
    }

    if (allTags.isEmpty && _selectedTag == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Row(
            children: [
              const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              const Text('Tag:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              const SizedBox(width: 6),
              if (_selectedTag != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InputChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF0284C7),
                    label: Text('#$_selectedTag', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    onDeleted: () {
                      setState(() => _selectedTag = null);
                      _loadDocuments();
                    },
                    deleteIconColor: Colors.white,
                  ),
                ),
              ...allTags.where((t) => t != _selectedTag).map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF334155)),
                    label: Text('#$t', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    onPressed: () {
                      setState(() => _selectedTag = t);
                      _loadDocuments();
                    },
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedDocType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: const Color(0xFF0284C7),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
        onSelected: (selected) {
          setState(() => _selectedDocType = selected ? value : '');
          _loadDocuments();
        },
      ),
    );
  }

  Widget _buildDocumentCard(DocumentItem doc) {
    Color badgeColor;
    String badgeText;

    if (doc.permissionLevel == 'owner') {
      badgeColor = const Color(0xFF10B981); // Emerald
      badgeText = 'Chủ sở hữu (Owner)';
    } else if (doc.permissionLevel == 'edit') {
      badgeColor = const Color(0xFF38BDF8); // Sky
      badgeText = 'Được phép sửa (Editor)';
    } else {
      badgeColor = const Color(0xFFF59E0B); // Amber
      badgeText = 'Chỉ xem (Viewer)';
    }

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: badgeColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card: Tag loại + Badge quyền + Menu nút 3 chấm
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    doc.docTypeLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: const Color(0xFF1E293B),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditDocumentScreen(document: doc)),
                      );
                      if (res == true) _loadDocuments();
                    } else if (val == 'share') {
                      if (!doc.isOwner) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('RLS Chặn: Chỉ chủ sở hữu (Owner) mới có quyền chia sẻ tài liệu!'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShareScreen(document: doc)),
                      );
                    } else if (val == 'borrow') {
                      try {
                        await DocumentService().requestBorrow(doc.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã gửi yêu cầu mượn "${doc.title}".'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e'), backgroundColor: Colors.orange),
                          );
                        }
                      }
                    } else if (val == 'download') {
                      _downloadFile(doc);
                    } else if (val == 'delete') {
                      _deleteDocument(doc);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (doc.storagePath != null && doc.storagePath!.isNotEmpty)
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: const [
                            Icon(Icons.download_rounded, color: Color(0xFF38BDF8), size: 18),
                            SizedBox(width: 8),
                            Text('Tải / Xem tệp', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: doc.canEdit ? Colors.white : Colors.white30, size: 18),
                          const SizedBox(width: 8),
                          Text('Chỉnh sửa', style: TextStyle(color: doc.canEdit ? Colors.white : Colors.white30)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, color: doc.isOwner ? Colors.white : Colors.white30, size: 18),
                          const SizedBox(width: 8),
                          Text('Chia sẻ quyền', style: TextStyle(color: doc.isOwner ? Colors.white : Colors.white30)),
                        ],
                      ),
                    ),
                    if (!doc.isOwner)
                      PopupMenuItem(
                        value: 'borrow',
                        child: Row(
                          children: const [
                            Icon(Icons.handshake_outlined, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text('Yêu cầu mượn', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(height: 8),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: doc.isOwner ? Colors.redAccent : Colors.white30, size: 18),
                          const SizedBox(width: 8),
                          Text('Xóa tài liệu', style: TextStyle(color: doc.isOwner ? Colors.redAccent : Colors.white30)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tiêu đề
            Text(
              doc.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),

            // Thông tin chi tiết: Môn học, Tác giả, Năm
            Row(
              children: [
                const Icon(Icons.school_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(doc.subject, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                const SizedBox(width: 16),
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(doc.author, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('${doc.year}', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ],
            ),

            if (doc.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: doc.tags.map((t) {
                  final isCurrentTag = _selectedTag == t;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedTag = isCurrentTag ? null : t;
                      });
                      _loadDocuments();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCurrentTag
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrentTag ? Colors.white : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrentTag ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentTag ? Colors.white : const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (doc.locationLabel != null && doc.locationLabel!.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: (doc.latitude != null && doc.longitude != null)
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              mode: MapScreenMode.viewDocuments,
                              documents: [doc],
                              initialLocation: null,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Vị trí: ${doc.locationLabel}${doc.latitude != null ? ' (Bấm xem bản đồ)' : ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doc.latitude != null && doc.longitude != null)
                      const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ],

            if (doc.storagePath != null && doc.storagePath!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 20, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tệp đính kèm (Storage Private):',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                          ),
                          Text(
                            doc.storagePath!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _downloadingDocId == doc.id ? null : () => _downloadFile(doc),
                      icon: _downloadingDocId == doc.id
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 15),
                      label: Text(
                        _downloadingDocId == doc.id ? 'Đang mở...' : 'Tải về',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
